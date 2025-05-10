# auto-vps-deploy

自动化完成 Nginx、SSL、Python 项目列表、systemd 服务列表等部署。

## 目录结构

- `example.com.sh`  —— 主部署脚本，自动解析 CSV，配置 Nginx、SSL、拉取代码、生成 .env、升级与卸载脚本、systemd 服务等
- `example.com.csv` —— 每个服务的参数和环境变量配置（可多行）
- `example.com.py`  —— 上传脚本，自动将同名的 `.sh` 和 `.csv` 上传到远程 VPS

## 快速使用

### 1. 编辑 CSV 服务列表

- 复制 `example.com.sh` 和 `example.com.csv`，重命名为你的域名（如 `mydomain.com.sh`、`mydomain.com.csv`）。
- 按格式填写 CSV，每行一个服务，后续字段为环境变量。

### 2. 上传脚本和 CSV 到 VPS, 如果使用 python 脚本上传的话:

- 配置 .env: 在本地目录下新建 `.env`，内容示例：

```env
PASSWARD=你的VPS密码
DIR=/opt
```

- 一键上传

```bash
python example.com.py
```

### 3. 远程 VPS 上执行

SSH 登录你的 VPS，进入上传目录，运行：

```bash
bash example.com.sh
```

脚本会自动完成 Nginx 配置、SSL 证书申请、代码拉取、.env 生成、升级 卸载脚本生成、Python 依赖安装、systemd 服务注册等。

---

## CSV 配置说明

CSV 文件用于批量描述每个要部署的服务。 **每一行代表一个服务** ，字段顺序和含义如下：

| 字段名        | 说明                                      | 示例                                                    |
| ------------- | ----------------------------------------- | ------------------------------------------------------- |
| `_GIT`      | 代码仓库地址（git clone用）               | `https://github.com/xxxx/xxxx.git`                    |
| `DIR`       | 代码部署目录（绝对路径）                  | `/opt/service1`                                       |
| `SUBDOMAIN` | 服务的子域名（会拼接主域名）              | `service1`                                            |
| `PORT`      | 后端服务监听端口  (配置反向代理到此端口) | `1234`                                                |
| `NAME`      | 服务名（用于 systemd、显示等）            | `service1`                                            |
| `CMD`       | 启动命令（绝对路径，目前只支持 python）   | `/opt/sevice1/.venv/bin/python3 /opt/service1/app.py` |
| `ENV...`    | 任意数量的环境变量（格式：KEY=VALUE）     | `PORT=1234`、`TOKEN=xxxx`、`CACHE_SIZE_GB=3` 等   |

* **每行一个服务** ，可批量部署多个服务。
* **前6列必须有，后面可以有任意多个环境变量字段。**
* 环境变量字段数量不限，自动写入对应服务的 [.env](vscode-file://vscode-app/c:/Users/lzh/AppData/Local/Programs/Microsoft%20VS%20Code/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html) 文件。
* 环境变量字段可以留空，不会写入 [.env](vscode-file://vscode-app/c:/Users/lzh/AppData/Local/Programs/Microsoft%20VS%20Code/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html)。

## 注意事项

- 需 root 权限运行 shell 脚本
- csv 文件字段缺失或顺序错误会导致脚本异常
- `CMD` 推荐用绝对路径，确保 systemd 能正确启动。
- 字段内容建议用英文双引号包裹，防止逗号冲突。

---

## LICENSE

MIT
