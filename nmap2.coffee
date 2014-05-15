Promise = require("promise")
fs      = require("fs")
cp      = require('child_process')
xml2js  = require("xml2js")

nmap = (iprange)->
  new Promise (resolve, reject)->
    cp.exec "nmap -sP #{iprange} -oX .nmap.xml", (err, stdout, stderr)->
      if err
      then reject(tderr)
      else fs.readFile ".nmap.xml", "utf-8", (err, str)->
        if err
        then reject(err)
        else cp.exec "rm .nmap.xml", (err, stdout, stderr)->
          if err
          then reject(stderr)
          else resolve xml2js.parseString str, (err, json)->
            if err
            then reject(err)
            else resolve json.nmaprun.host.reduce(((lst, host)->
              lst.concat host.address.reduce(((obj, address)->
                {addr, addrtype} = address.$
                obj[addrtype] = addr
                obj
              ), {})
            ), []).reduce(((lst, addr)->
              if addr.mac? and addr.ipv4?
              then lst.concat(addr)
              else lst
            ), [])


_       = require("underscore")

transaction = (connection)-> (addrs)->
  new Promise (resolve, reject)->
    connection.connect (err)->
      if err
      then reject(err)
      else
        date = Date.now()
        fields = addrs.map ({mac, ipv4})-> "(#{date}, '#{mac}', '#{ipv4}')"
        if fields.length is 0
        then resolve(addrs)
        else connection.query "INSERT INTO details VALUES " + fields.join(", ") + ";", (err, results)->
          if err
          then reject(err)
          else connection.query "SELECT * FROM devices;", (err, devices)->
            if err
            then reject(err)
            else
              a = devices.map ({mac})-> mac
              b = addrs.map ({mac})-> mac
              c = _.difference(b, _.intersection(a, b))
              strangeaddrs = addrs.filter ({mac})->  _.indexOf(c, mac) >= 0
              fields2 = strangeaddrs.map ({mac, ipv4})-> "('#{mac}', '')"
              if fields2.length is 0
              then resolve({addrs, devices})
              else connection.query "INSERT INTO devices VALUES " + fields2.join(", ") + ";", (err, results)->
                console.log("d")
                if err
                then reject(err)
                else resolve({addrs, devices})

ipv4ToNum = (addr)->
  a = addr
    .split(".")
    .map((str)-> (Number(str)+16*16).toString(16).slice(1))
    .join("")
  parseInt(a, 16)

macToNum = (addr)->
  a = addr.split(":").map((n)->n.toUpperCase()).join("")
  parseInt(a, 16)

numToMac = (num)->
  [/(..)(..)(..)(..)(..)(..)/.exec((Number(num)+Math.pow(16*16,6)).toString(16).slice(1)) or ""][0].slice(1).join(":").toUpperCase()

numToIPv4 = (num)->
  [/(..)(..)(..)(..)/.exec(Number(num).toString(16)) or ""][0].slice(1).map((str)-> parseInt(str, 16)).join(".")


express = require('express')
sockets = require("socket.io")
mysql   = require("mysql")

server = express()
  .disable('x-powered-by')
  .use(express.static(__dirname + '/htdocs'))
  .listen(80)

io = sockets.listen(server)
io.sockets.on "connection", (socket)->
  console.log "ip:"+socket.handshake.address.address

oldaddrs = []
do interval = ->
  connection = mysql.createConnection({
    host: "localhost"
    user: ""
    password: ""
    database: ""
  })
  nmap("192.168.1.1-244")
    .then(transaction(connection))
    .then (({addrs, devices})->
        console.log new Date()
        a = oldaddrs.map ({mac})-> mac
        b = addrs.map ({mac})-> mac
        came = _.difference(a, _.intersection(a, b))
        left = _.difference(b, _.intersection(a, b))
        hash = devices.reduce(((o, {mac, nickname})->
          o[mac] = nickname
          o
        ), {})
        addrlist = addrs.reduce(((lst, {ipv4, mac})->
          lst.concat {ipv4, mac, nickname: hash[mac]}
        ), [])
        console.log "live"
        console.log addrlist.map(({ipv4, mac, nickname})-> ipv4+"\t"+mac+"\t"+nickname).join("\n")
        console.log "came"
        console.log came.map((mac)-> mac+"\t"+hash[mac]).join("\n")
        console.log "left"
        console.log left.map((mac)-> mac+"\t"+hash[mac]).join("\n")
        oldaddrs = addrs
        connection.end()
        io.sockets.emit("update", addrlist)
        setTimeout interval, 10*60*1000
    ), (err)->
        console.dir err
        connection.end()

