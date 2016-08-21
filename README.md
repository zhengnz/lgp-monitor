#Log + Git + Pm2管理工具

##如何使用？
---
    npm install -g pm2@next
    pm2 install lgp-monitor
---

##设置端口
---
    pm2 set lgp-monitor:port your_port
---

##扩展/自定义

###扩展/自定义分两种情况，一种是面向接口的，一种是面向页面的

###面向页面可参考代码中的website.js

###面向接口可参考代码中的server.js

###自定义完成后可以通过以下方式设置

---
    pm2 set lgp-monitor:website /path/to/your/website.js
    pm2 set lgp-monitor:server /path/to/your/server.js
---