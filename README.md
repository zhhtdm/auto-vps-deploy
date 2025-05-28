# auto vps deploy
根据配置表自动部署服务 (目前支持部署 pytho、node.js 服务到 Debian 系服务器)
## 流程
- 安装 Nginx, Certbot, Git, Python
- 针对每个服务:
    - 申请子域名的 SSL 证书
    - 配置反向代理
    - 克隆 git 仓库
    - 生成`.env`文件
    - 安装对应的`python`或`node.js`环境和依赖
    - 生成卸载脚本`uninstall.sh`
    - 生成版本更新脚本`upgrade.sh`
    - 配置`systemctl`

## 配置表
- 可以在脚本中编写配置字符串，也可以编写到外部与脚本同名的`csv`文件中
- 外部`csv`配置文件优先级大于脚本中的配置字符串
- 每条配置对应一个服务，由 7 个字段构成，顺序固定
- 第 7 段为服务的环境变量，由不定数量的子段构成

### 字段
| 字段名      | 说明                                  | 示例                                                  |
| ----------- | ------------------------------------- | ----------------------------------------------------- |
| `_GIT`      | 代码仓库地址（git clone用）           | `https://github.com/xxxx/xxxx.git`                    |
| `DIR`       | 代码部署目录（绝对路径）              | `/opt/service1`                                       |
| `SUBDOMAIN` | 服务的子域名（会拼接主域名）          | `service1`                                            |
| `PORT`      | 后端服务监听端口  (配置反向代理)      | `1234`                                                |
| `NAME`      | 服务名（用于 systemd、显示等）        | `service1`                                            |
| `CMD`       | 启动命令（绝对路径）                  | `/opt/sevice1/.venv/bin/python3 /opt/service1/app.py` |
| `ENV`       | 任意数量的环境变量（格式：KEY=VALUE） | `APP_PATH=/`、`PORT=1234`、`TOKEN=xxxx` 等            |

### 示例
脚本中配置字符串用`|`分隔主段，用`,`分隔环境变量中的子段，示例:
```bash
PROJECTS=(
    'https://github.com/xxx/server1.git|/opt/server1|server1|1234|server1|/opt/server1/.venv/bin/python3 /opt/server1/app.py|PORT=1234,TOKEN=xxxx'
    'https://github.com/xxx/server2.git|/opt/server2|server2|1235|server2|/opt/server2/.venv/bin/python3 /opt/server2/app.py|XXX=XXX,XXX=xxxx,XXX=XXX'
    'https://github.com/xxx/server3.git|/opt/server3|server3|1236|server3|/opt/server3/.venv/bin/python3 /opt/server3/app.py'
    'https://github.com/atmos/camo.git|/opt/camo|camo|8081|camo|/usr/bin/env PORT=8081 CAMO_KEY=0x24FEEDFACEDEADBEEFCAFE CAMO_KEEP_ALIVE=false /usr/bin/node /opt/camo/server.js'

)
```
`csv`配置文件中前 6 列为前 6 个主段，之后每个环境变量都各占一列，若首行为表头则会跳过首行，建议每个单元格内容都用双引号包裹，示例:
```csv
"_GIT","DIR","SUBDOMAIN","PORT","NAME","CMD",,,
"https://github.com/xxxx/xxxx1.git","/opt/service1","service1","1234","service1","/opt/service1/.venv/bin/python3 /opt/service1/app.py","PORT=1234","TOKEN=xxxx",
"https://github.com/xxxx/xxxx2.git","/opt/service2","service2","1235","service2","/opt/service2/.venv/bin/python3 /opt/service2/app.py","PORT=1235","TOKEN=xxxx","PASSWARD=xxxx"
"https://github.com/atmos/camo.git","/opt/camo","camo","8081","camo","/usr/bin/env PORT=8081 CAMO_KEY=0x24FEEDFACEDEADBEEFCAFE CAMO_KEEP_ALIVE=false /usr/bin/node /opt/camo/server.js"

```
## 使用
1. 更改脚本中`EMAIL`变量`EMAIL="xxx@xxxxx.com"`为合法邮箱，否则申请 SSL 证书可能失败
2. 脚本重命名为服务器主域名.sh
3. 编辑配置表
4. 使用 root 权限运行脚本
