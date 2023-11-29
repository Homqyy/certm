# CertManager

证书管理工具

## 部署和使用

1. 设置配置文件 `settings.conf`：

    ```text
    g_conf_name="YourName"
    g_conf_domain_suffix=domain.example.cn
    g_conf_organization="YourOrganization"
    g_conf_organization_unit="Your OUnit"
    g_conf_password=root
    ```

    - `g_conf_name`：证书拥有者名称
    - `g_conf_domain_suffix`：证书域名后缀，也决定后续可以生成的证书域名
    - `g_conf_organization`：证书拥有者所属组织
    - `g_conf_organization_unit`：证书拥有者所属组织单元
    - `g_conf_password`：CA密钥的密码

2. 克隆仓库到Linux主机上

    ```bash
    https://github.com/Homqyy/certm.git 
    ```

3. 构建并安装“Certm”：

    ```bash
    ./build.sh -i
    ```

4. 安装成功后，可以使用“certm-*”命令完成证书的生成和管理。

### certm-mkcert

生成证书工具；生成的证书会放到`output/clients`和`output/servers`目录中，这取决于生成的是客户端证书还是服务器证书。并且在其中还会有子目录`gm`和`rsa`，分别存放GM证书和RSA证书。

使用方法：

```bash
Usage: /home/admin/workspaces/certm/src/tools/mkcert.sh [OPTIONS] <domain_name>
Options:
  -h, --help          Show help
  -d, --debug         Enable debug mode
  -g, --gm            Enable gm
  -s, --server        Server certificate, default is client
  -b, --begin <DATE>  Begin date, default is now
  -e, --end   <DATE>  End date, default is 1095 days

DATE: format is YYYYMMDDHHMMSSZ, such as 20201027120000Z

Example: /home/admin/workspaces/certm/src/tools/mkcert.sh example
```

- `domain_name`：证书域名，可以是二级域名，也可以是三级域名，它会自动跟域名后缀`g_conf_domain_suffix`拼接成完整的域名，比如`example`会拼接成`example.example.cn`。
- `-d/--debug`：是否开启调试模式，开启后会打印脚本执行的过程
- `-g/--gm`：是否生成GM证书（SM2证书）
- `-s/--server`：是否生成服务器证书，默认是客户端证书
- `-b/--begin`：证书生效时间，默认是当前时间
- `-e/--end`：证书失效时间，默认是1095天后

生成证书时，会将证书信息打印到标准输出，你可以检查证书信息是否正确，如果正确则按`y`表示同意生成证书，否则按`n`表示不生成证书：

![mkcert-mkcert](/docs/assets/certm-mkcert.png)

### certm-genca

导出CA证书工具；会将CA导出到`output/ca`目录中，使用方法：

```bash
certm-genca
```

查看`output/ca`目录：

```text
[admin@cloud certm]$ ls -l output/ca/
total 32
-rw-rw-r-- 1 admin admin 2543 Nov 29 09:48 ca-all.pem.crt
-rw-rw-r-- 1 admin admin 1807 Nov 29 09:48 ca-chain-gm.pem.crt
-rw-rw-r-- 1 admin admin 4221 Nov 29 09:48 ca-chain.pem.crt
-rw-rw-r-- 1 admin admin  664 Nov 29 09:48 ca-gm.pem.crt
-rw-rw-r-- 1 admin admin 1879 Nov 29 09:48 ca.pem.crt
```

- `ca-all.pem.crt`：包含所有CA证书的证书链（GM和RSA）
- `ca-chain-gm.pem.crt`：包含GM证书链的证书链（根证书和中间证书）
- `ca-chain.pem.crt`：包含RSA证书链的证书链（根证书和中间证书）
- `ca-gm.pem.crt`：GM根证书
- `ca.pem.crt`：RSA根证书

### certm-gencrl

导出CRL工具；会将CRL导出到`output/ca`目录中，使用方法：

```bash
certm-gencrl
```

### certm-revoke

吊销证书工具；使用方法：

```bash
[admin@cloud certm]$ certm-revoke 
Usage: /home/admin/workspaces/certm/src/tools/revoke.sh [OPTIONS] <domain_name>
Options:
  -h, --help          Show help
  -s, --server        Server certificate, default is client
  -g, --gm            GM Certificate, default is rsa
```

- `domain_name`：证书域名，与`certm-mkcert`命令生成证书时的域名一致
- `-s/--server`：是否是服务器证书，默认是客户端证书
- `-g/--gm`：是否是GM证书，默认是RSA证书

## build.sh

```bash
Usage: ./build.sh [options]
Options:
  -h, --help      Show this help message and exit
  -c, --clean     Clean all the build files: dependencies + certm
  -d, --debug     Enable debug mode
  -i, --install   Install certm
  -u, --uninstall Uninstall certm
  -r, --rebuild   Rebuild certm
```

- `-c/--clean`：清除所有构建文件，包括依赖的库和certm；相当于恢复到刚克隆仓库时的状态。
- `-d/--debug`：开启调试模式，会打印脚本执行过程。
- `-i/--install`：安装certm；安装后可以使用`certm-*`工具集。
- `-u/--uninstall`：卸载certm。
- `-r/--rebuild`：重新构建certm；会删除`output`目录，因此如果此目录的结果还有用，请及时拷贝走。