#Log + Git + Pm2管理工具

##如何使用？
---
    npm install -g pm2@next
    pm2 install lgp-monitor
---
***启动完成后浏览器访问http://127.0.0.1:3001，如果pm2添加或删除项目后，请执行pm2 restart lgp-monitor***

##设置端口
---
    pm2 set lgp-monitor:port your_port
---

##分组
当我们的项目有些多的时候，列表看起来很杂乱，我们可以来为项目分组在pm2的配置文件中添加环境变量MONITOR_GROUP，这样看起来就干净多了

##扩展/自定义

###扩展/自定义分两种情况，一种是面向接口的，一种是面向页面的

###面向页面可参考代码中的website.js

###面向接口可参考代码中的server.js

###自定义完成后可以通过以下方式设置

---
    pm2 set lgp-monitor:website /path/to/your/website.js
    pm2 set lgp-monitor:server /path/to/your/server.js
---