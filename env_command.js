var shell = require('shelljs');
var _ = require('lodash');

process.on('message', function (m) {
    _.forEach(JSON.parse(m.env), function (value, key) {
        shell.env[key] = value;
    });
    var child = shell.exec(m.cmd, {async:true});
    child.stdout.on('data', function(data) {
        process.send({msg: data});
    });
    child.stderr.on('data', function(data) {
        process.send({msg: data});
    });
    child.on('close', function () {
        process.exit(0);
    })
});