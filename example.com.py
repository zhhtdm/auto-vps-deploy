import os
import paramiko
from dotenv import load_dotenv

load_dotenv()  # 默认加载当前目录下的 .env 文件

# 获取当前脚本文件名（不含扩展名）
script_name = os.path.splitext(os.path.basename(__file__))[0]

# 构造需要上传的两个文件名
sh_file = f"{script_name}.sh"
csv_file = f"{script_name}.csv"

# 检查文件是否存在
for f in [sh_file, csv_file]:
	if not os.path.isfile(f):
		print(f"❌ File not found: {f}")
		exit(1)

# 远程主机信息
hostname = script_name  # 脚本名即域名
username = "root"
password = os.getenv("PASSWARD", "")
remote_path = os.getenv("DIR", "/opt")

# 建立 SSH 连接并上传文件
try:
	transport = paramiko.Transport((hostname, 22))
	transport.connect(username=username, password=password)

	sftp = paramiko.SFTPClient.from_transport(transport)
	sftp.put(sh_file, f"{remote_path}/{sh_file}")
	sftp.put(csv_file, f"{remote_path}/{csv_file}")

	print(f"✅ Uploaded {sh_file} and {csv_file} to {hostname}:{remote_path}")

	sftp.close()
	transport.close()

except Exception as e:
	print(f"❌ Error: {e}")

finally:
	input("\nPress Enter to exit...")
