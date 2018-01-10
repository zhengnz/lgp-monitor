// Generated by CoffeeScript 1.12.6
(function() {
  var Promise, Server, _, events, exec, fs, hprose, os, pm2, shell;

  hprose = require('hprose');

  _ = require('lodash');

  events = require('events');

  Promise = require('bluebird');

  exec = require('child_process').exec;

  pm2 = require('pm2');

  fs = require('fs');

  os = require('os');

  shell = require('shelljs');

  Promise.promisifyAll(pm2);

  Server = (function() {
    function Server() {
      this.push_recorder = {};
      this.server = new hprose.HttpService();
      this.server.add({
        get_app_list: this.get_app_list.bind(this),
        reload: this.reload_app.bind(this),
        restart: this.restart_app.bind(this),
        git: this.git.bind(this),
        git_rollback: this.git_rollback.bind(this),
        get_git_commits: this.get_git_commits.bind(this),
        npm_install: this.npm_install.bind(this),
        js_compile: this.js_compile.bind(this),
        client_exit: this.client_exit.bind(this)
      });
      this.init_publish();
      this.server.publish('console');
      this.forbid_restart = false;
      process.on('SIGINT', (function(_this) {
        return function() {
          _this.forbid_restart = true;
          return _.each(_.keys(_this.push_recorder), function(name) {
            return _this.end_push_log(name);
          });
        };
      })(this));
    }

    Server.prototype.cmd = function(msg, cwd) {
      if (cwd == null) {
        cwd = __dirname;
      }
      return new Promise(function(resolve, reject) {
        return exec(msg, {
          cwd: cwd
        }, function(err, stdout, stderr) {
          if (err) {
            return reject(err);
          }
          return resolve([stdout, stderr]);
        });
      });
    };

    Server.prototype.true_app_list = function() {
      return pm2.listAsync().then(function(list) {
        return list;
      });
    };

    Server.prototype.get_git_version = function(path) {
      return this.cmd("cd " + path + " && git rev-parse HEAD").spread(function(stdout, stderr) {
        if (stderr) {
          return Promise.reject(new Error(stderr));
        }
        return Promise.resolve(stdout);
      });
    };

    Server.prototype.get_git_source = function(path) {
      return this.cmd("cd " + path + " && git config --get remote.origin.url").spread(function(stdout, stderr) {
        if (stderr) {
          return Promise.reject(new Error(stderr));
        }
        return Promise.resolve(stdout);
      });
    };

    Server.prototype.get_app_list = function(has_cwd) {
      if (has_cwd == null) {
        has_cwd = false;
      }
      return this.true_app_list().then((function(_this) {
        return function(apps) {
          return Promise.map(apps, function(app) {
            var path;
            path = app.pm2_env.pm_cwd;
            return new Promise(function(resolve, reject) {
              return fs.exists(path + "/.git", function(exists) {
                var obj;
                obj = {
                  name: app.name,
                  git: exists,
                  mode: app.pm2_env.exec_mode,
                  branch: 'master'
                };
                if (_.has(app.pm2_env.env, 'MONITOR_GROUP')) {
                  obj.group = app.pm2_env.env.MONITOR_GROUP;
                }
                if (_.has(app.pm2_env.env, 'GIT_BRANCH')) {
                  obj.branch = app.pm2_env.env.GIT_BRANCH;
                }
                if (_.has(app.pm2_env.env, 'JS_COMPILE')) {
                  obj.js_compile = app.pm2_env.env.JS_COMPILE;
                } else {
                  obj.js_compile = false;
                }
                if (has_cwd === true) {
                  obj.cwd = path;
                }
                return resolve(obj);
              });
            }).then(function(obj) {
              if (!obj.git) {
                obj.git_version = '';
                return Promise.resolve(obj);
              } else {
                return Promise.all([_this.get_git_version(path), _this.get_git_source(path)]).then(function(results) {
                  var source, version;
                  version = results[0], source = results[1];
                  obj.git_version = version;
                  obj.git_source = source;
                  return Promise.resolve(obj);
                });
              }
            });
          });
        };
      })(this));
    };

    Server.prototype.start_push_log = function(name) {
      var cmd;
      if (this.push_recorder[name].cmd === null) {
        this.console("开始输出" + name + "的日志");
      }
      cmd = exec("pm2 logs " + name);
      cmd.stdout.on('data', (function(_this) {
        return function(data) {
          return _this.server.push(name, data);
        };
      })(this));
      cmd.on('exit', (function(_this) {
        return function() {
          if (_this.server.idlist(name) > 0 && _this.forbid_restart === false) {
            return _this.start_push_log(name);
          } else {
            return _this.push_recorder[name].cmd = null;
          }
        };
      })(this));
      return this.push_recorder[name].cmd = cmd;
    };

    Server.prototype.end_push_log = function(name) {
      if (this.push_recorder[name].cmd != null) {
        this.console("结束输出" + name + "的日志");
        if (os.platform() === 'win32') {
          return exec("taskkill /pid " + this.push_recorder[name].cmd.pid + " /T /F");
        } else {
          return this.push_recorder[name].cmd.kill();
        }
      }
    };

    Server.prototype.init_publish = function() {
      return this.true_app_list().then((function(_this) {
        return function(apps) {
          return _.map(apps, function(app) {
            var name, push_events;
            name = app.name;
            _this.push_recorder[name] = {
              pushing: false,
              cmd: null
            };
            push_events = new events.EventEmitter();
            push_events.on('subscribe', function(id, context) {
              if (_this.push_recorder[name].pushing === true) {
                return;
              }
              _this.push_recorder[name].pushing = true;
              return _this.start_push_log(name);
            });
            push_events.on('unsubscribe', function(id, context) {
              _this.console(id + "退订，剩余" + (_this.server.idlist(name).length) + "个客户端");
              if (_this.server.idlist(name).length === 0) {
                _this.push_recorder[name].pushing = false;
                return _this.end_push_log(name);
              }
            });
            return _this.server.publish(name, {
              events: push_events
            });
          });
        };
      })(this));
    };

    Server.prototype.client_exit = function(name) {
      this.server.push(name, 'CLIENT EXIT');
      return true;
    };

    Server.prototype.console = function(msg) {
      return this.server.push('console', msg + "\n");
    };

    Server.prototype.reload_app = function(name) {
      this.console("重载" + name + "中，请稍等...");
      return pm2.reloadAsync(name).then((function(_this) {
        return function() {
          _this.console("重载" + name + "完成");
          return Promise.resolve();
        };
      })(this));
    };

    Server.prototype.restart_app = function(name) {
      this.console("重启" + name + "中，请稍等...");
      return pm2.restartAsync(name).then((function(_this) {
        return function() {
          _this.console("重启" + name + "完成");
          return Promise.resolve();
        };
      })(this));
    };

    Server.prototype.get_git_path = function(name) {
      return this.get_app_list(true).then((function(_this) {
        return function(apps) {
          var app;
          app = _.find(apps, function(_app) {
            return _app.name === name && _app.git === true;
          });
          if (app === void 0) {
            return Promise.reject(new Error('无匹配的应用'));
          }
          return Promise.resolve(app.cwd);
        };
      })(this));
    };

    Server.prototype.get_git_branch = function(name) {
      return this.get_app_list(true).then((function(_this) {
        return function(apps) {
          var app;
          app = _.find(apps, function(_app) {
            return _app.name === name && _app.git === true;
          });
          if (app === void 0) {
            return Promise.reject(new Error('无匹配的应用'));
          }
          return Promise.resolve(app.branch);
        };
      })(this));
    };

    Server.prototype.git = function(name, branch) {
      var path;
      path = null;
      return this.get_git_path(name).then((function(_this) {
        return function(p) {
          var cmd;
          path = p;
          cmd = "git pull origin " + branch;
          _this.console("开始git同步, 目录: " + path);
          _this.console(cmd);
          return _this.cmd(cmd, path);
        };
      })(this)).spread((function(_this) {
        return function(stdout, stderr) {
          _this.console(stderr);
          _this.console(stdout);
          return _this.get_git_version(path);
        };
      })(this));
    };

    Server.prototype.get_git_commits = function(name) {
      return this.get_git_path(name).then((function(_this) {
        return function(path) {
          var format;
          format = '{\\"id\\": \\"%H\\", \\"msg\\": \\"%s\\", \\"time\\": \\"%cd\\"}';
          return _this.cmd("cd " + path + " && git log --pretty=format:\"" + format + "\" -10");
        };
      })(this)).spread((function(_this) {
        return function(stdout, stderr) {
          var arr;
          if (stderr) {
            return Promise.reject(new Error(stderr));
          }
          arr = _.split(stdout, /\n/g);
          arr = _.filter(arr, function(obj) {
            return obj !== '';
          });
          arr = _.map(arr, function(obj) {
            return JSON.parse(obj);
          });
          return Promise.resolve(arr);
        };
      })(this));
    };

    Server.prototype.git_rollback = function(name, commit_id) {
      var path;
      this.console(name + "开始回滚到" + commit_id);
      path = null;
      return this.get_git_path(name).then((function(_this) {
        return function(p) {
          path = p;
          return _this.cmd("cd " + path + " && git reset --hard " + commit_id);
        };
      })(this)).spread((function(_this) {
        return function(stdout, stderr) {
          _this.console(stderr);
          _this.console(stdout);
          return _this.get_git_version(path);
        };
      })(this)).then((function(_this) {
        return function(version) {
          _this.console(name + "当前版本: " + version);
          return Promise.resolve(version);
        };
      })(this));
    };

    Server.prototype.get_project_path = function(name) {
      return this.get_app_list(true).then((function(_this) {
        return function(apps) {
          var app;
          app = _.find(apps, function(_app) {
            return _app.name === name;
          });
          if (app === void 0) {
            return Promise.reject(new Error('无匹配的应用'));
          }
          return Promise.resolve(app.cwd);
        };
      })(this));
    };

    Server.prototype.run_npm = function() {
      if (shell.which('yarn')) {
        return 'yarn';
      } else {
        return 'npm';
      }
    };

    Server.prototype.npm_install = function(name) {
      return this.get_project_path(name).then((function(_this) {
        return function(p) {
          var cmd, path;
          path = p;
          cmd = (_this.run_npm()) + " install --production";
          _this.console("开始安装, 目录: " + path);
          _this.console(cmd);
          return _this.cmd(cmd, path);
        };
      })(this)).spread((function(_this) {
        return function(stdout, stderr) {
          _this.console(stderr);
          return _this.console(stdout);
        };
      })(this));
    };

    Server.prototype.js_compile = function(name, value) {
      return this.get_project_path(name).then((function(_this) {
        return function(p) {
          var child, cmd, path;
          path = p;
          cmd = "cd " + path + " && rm -rf node_modules && " + (_this.run_npm()) + " install && " + (_this.run_npm()) + " run " + value;
          _this.console("开始编译, 目录: " + path);
          child = shell.exec(cmd, {
            async: true
          });
          child.stdout.on('data', function(data) {
            return _this.console(data);
          });
          return child.stderr.on('data', function(data) {
            return _this.console("err: " + data);
          });
        };
      })(this));
    };

    Server.prototype.start = function() {
      return this.server.start();
    };

    return Server;

  })();

  module.exports = Server;

}).call(this);

//# sourceMappingURL=server.js.map
