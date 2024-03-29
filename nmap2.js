// Generated by CoffeeScript 1.6.3
(function() {
  var Promise, cp, express, fs, interval, io, ipv4ToNum, macToNum, mysql, nmap, numToIPv4, numToMac, oldaddrs, server, sockets, transaction, xml2js, _;

  Promise = require("promise");

  fs = require("fs");

  cp = require('child_process');

  xml2js = require("xml2js");

  nmap = function(iprange) {
    return new Promise(function(resolve, reject) {
      return cp.exec("nmap -sP " + iprange + " -oX .nmap.xml", function(err, stdout, stderr) {
        if (err) {
          return reject(tderr);
        } else {
          return fs.readFile(".nmap.xml", "utf-8", function(err, str) {
            if (err) {
              return reject(err);
            } else {
              return cp.exec("rm .nmap.xml", function(err, stdout, stderr) {
                if (err) {
                  return reject(stderr);
                } else {
                  return resolve(xml2js.parseString(str, function(err, json) {
                    if (err) {
                      return reject(err);
                    } else {
                      return resolve(json.nmaprun.host.reduce((function(lst, host) {
                        return lst.concat(host.address.reduce((function(obj, address) {
                          var addr, addrtype, _ref;
                          _ref = address.$, addr = _ref.addr, addrtype = _ref.addrtype;
                          obj[addrtype] = addr;
                          return obj;
                        }), {}));
                      }), []).reduce((function(lst, addr) {
                        if ((addr.mac != null) && (addr.ipv4 != null)) {
                          return lst.concat(addr);
                        } else {
                          return lst;
                        }
                      }), []));
                    }
                  }));
                }
              });
            }
          });
        }
      });
    });
  };

  _ = require("underscore");

  transaction = function(connection, addrs, resolve, reject) {
    return connection.connect(function(err) {
      var date, fields;
      if (err) {
        return reject(err);
      } else {
        date = Date.now();
        fields = addrs.map(function(_arg) {
          var ipv4, mac;
          mac = _arg.mac, ipv4 = _arg.ipv4;
          return "(" + date + ", '" + mac + "', '" + ipv4 + "')";
        });
        if (fields.length === 0) {
          return resolve(addrs);
        } else {
          return connection.query("INSERT INTO details VALUES " + fields.join(", ") + ";", function(err, results) {
            if (err) {
              return reject(err);
            } else {
              return connection.query("SELECT * FROM devices;", function(err, devices) {
                var a, b, c, fields2, strangeaddrs;
                if (err) {
                  return reject(err);
                } else {
                  a = devices.map(function(_arg) {
                    var mac;
                    mac = _arg.mac;
                    return mac;
                  });
                  b = addrs.map(function(_arg) {
                    var mac;
                    mac = _arg.mac;
                    return mac;
                  });
                  c = _.difference(b, _.intersection(a, b));
                  strangeaddrs = addrs.filter(function(_arg) {
                    var mac;
                    mac = _arg.mac;
                    return _.indexOf(c, mac) >= 0;
                  });
                  fields2 = strangeaddrs.map(function(_arg) {
                    var ipv4, mac;
                    mac = _arg.mac, ipv4 = _arg.ipv4;
                    return "('" + mac + "', '')";
                  });
                  if (fields2.length === 0) {
                    return resolve({
                      addrs: addrs,
                      devices: devices
                    });
                  } else {
                    return connection.query("INSERT INTO devices VALUES " + fields2.join(", ") + ";", function(err, results) {
                      if (err) {
                        return reject(err);
                      } else {
                        return resolve({
                          addrs: addrs,
                          devices: devices
                        });
                      }
                    });
                  }
                }
              });
            }
          });
        }
      }
    });
  };

  ipv4ToNum = function(addr) {
    var a;
    a = addr.split(".").map(function(str) {
      return (Number(str) + 16 * 16).toString(16).slice(1);
    }).join("");
    return parseInt(a, 16);
  };

  macToNum = function(addr) {
    var a;
    a = addr.split(":").map(function(n) {
      return n.toUpperCase();
    }).join("");
    return parseInt(a, 16);
  };

  numToMac = function(num) {
    return [/(..)(..)(..)(..)(..)(..)/.exec((Number(num) + Math.pow(16 * 16, 6)).toString(16).slice(1)) || ""][0].slice(1).join(":").toUpperCase();
  };

  numToIPv4 = function(num) {
    return [/(..)(..)(..)(..)/.exec(Number(num).toString(16)) || ""][0].slice(1).map(function(str) {
      return parseInt(str, 16);
    }).join(".");
  };

  express = require('express');

  sockets = require("socket.io");

  mysql = require("mysql");

  server = express().disable('x-powered-by').use(express["static"](__dirname + '/htdocs')).listen(80);

  io = sockets.listen(server);

  io.sockets.on("connection", function(socket) {
    return console.log("ip:" + socket.handshake.address.address);
  });

  oldaddrs = [];

  (interval = function() {
    var connection;
    connection = mysql.createConnection({
      host: "localhost",
      user: "nmap",
      password: "0120",
      database: "nmaplog"
    });
    return nmap("192.168.111.1-244").then(transaction(connection)).then((function(_arg) {
      var a, addrlist, addrs, b, came, devices, hash, left;
      addrs = _arg.addrs, devices = _arg.devices;
      console.log(new Date());
      a = oldaddrs.map(function(_arg1) {
        var mac;
        mac = _arg1.mac;
        return mac;
      });
      b = addrs.map(function(_arg1) {
        var mac;
        mac = _arg1.mac;
        return mac;
      });
      came = _.difference(a, _.intersection(a, b));
      left = _.difference(b, _.intersection(a, b));
      hash = devices.reduce((function(o, _arg1) {
        var mac, nickname;
        mac = _arg1.mac, nickname = _arg1.nickname;
        o[mac] = nickname;
        return o;
      }), {});
      addrlist = addrs.reduce((function(lst, _arg1) {
        var ipv4, mac;
        ipv4 = _arg1.ipv4, mac = _arg1.mac;
        return lst.concat({
          ipv4: ipv4,
          mac: mac,
          nickname: hash[mac]
        });
      }), []);
      console.log("live");
      console.log(addrlist.map(function(_arg1) {
        var ipv4, mac, nickname;
        ipv4 = _arg1.ipv4, mac = _arg1.mac, nickname = _arg1.nickname;
        return ipv4 + "\t" + mac + "\t" + nickname;
      }).join("\n"));
      console.log("came");
      console.log(came.map(function(mac) {
        return mac + "\t" + hash[mac];
      }).join("\n"));
      console.log("left");
      console.dir(left.map(function(mac) {
        return mac + "\t" + hash[mac];
      }).join("\n"));
      oldaddrs = addrs;
      connection.end();
      io.sockets.emit("update", addrlist);
      return setTimeout(interval, 10 * 60 * 1000);
    }), function(err) {
      console.dir(err);
      return connection.end();
    });
  })();

}).call(this);
