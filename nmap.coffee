fs      = require("fs")
cp      = require('child_process')
xml2js  = require("xml2js")
Promise = require("promise")
mysql   = require("mysql")
_       = require("underscore")
express = require('express')
sockets = require("socket.io")

nmap = (iprange)->
  new Promise (resolve, reject)->
    cp.exec "nmap -sP #{iprange} -oX .nmap.xml", (err, stdout, stderr)->
#      console.log("a")
      if err
      then reject(tderr)
      else fs.readFile ".nmap.xml", "utf-8", (err, str)->
#        console.log("b")
        if err
        then reject(err)
        else cp.exec "rm .nmap.xml", (err, stdout, stderr)->
#          console.log("c")
          if err
          then reject(stderr)
          else resolve xml2js.parseString str, (err, json)->
#            console.log("d")
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

transaction = (connection)-> (addrs)->
  new Promise (resolve, reject)->
    connection.connect (err)->
#      console.log("a")
      if err
      then reject(err)
      else
        date = Date.now()
        fields = addrs.map ({mac, ipv4})-> "(#{date}, '#{mac}', '#{ipv4}')"
        if fields.length is 0
        then resolve(addrs)
        else connection.query "INSERT INTO details VALUES " + fields.join(", ") + ";", (err, results)->
#          console.log("b")
          if err
          then reject(err)
          else connection.query "SELECT * FROM devices;", (err, devices)->
#            console.log("c")
            if err
            then reject(err)
            else
              a = devices.map ({mac})-> mac
              b = addrs.map ({mac})-> mac
              c = _.difference(b, _.intersection(a, b))
              strangeaddrs = addrs.filter ({mac})->  _.indexOf(c, mac) >= 0
#              console.log "c-strange"
#              console.dir c
#              console.dir strangeaddrs
              fields2 = strangeaddrs.map ({mac, ipv4})-> "('#{mac}', '')"
#              console.dir fields2
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
        #cameaddr = addrs.filter ({mac})->  _.has(came, mac)
        #leftaddr = addrs.filter ({mac})->  _.has(left, mac)
#        console.dir devices
        hash = devices.reduce(((o, {mac, nickname})->
          o[mac] = nickname
          o
        ), {})
        addrlist = addrs.reduce(((lst, {ipv4, mac})->
          lst.concat {ipv4, mac, nickname: hash[mac]}
        ), [])
        console.log "live"
        console.dir addrlist
        console.log "came"
        console.dir came
        console.log "left"
        console.dir left
        oldaddrs = addrs
        connection.end()
        io.sockets.emit("update", addrlist)
        setTimeout interval, 10*60*1000
    ), (err)->
        console.dir err
        connection.end()
