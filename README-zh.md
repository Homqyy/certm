# CertManager

证书管理工具

## 开发计划

- [x] 支持ECDSA
- [x] 虚拟环境
- [x] 支持基于 CSR 文件生成证书
- [x] 重构`csr.conf`和`settings.conf`方案
- [ ] 支持设置ECDSA的曲线名
- [ ] 支持 renew 证书
- [x] 用`subenv`作为变量替换工具
- [ ] 用`json`作为配置文件的格式

## 部署和使用

1. 设置配置文件 `settings.conf`：

    ```text
    g_conf_name=YourName
    g_conf_domain_suffix=domain.example.cn
    g_conf_country_name=CN
    g_conf_state_or_province_name="Guang Dong"
    g_conf_locality_name="Shen Zhen"
    g_conf_organization_name=Personal
    g_conf_organization_unit_name=OUnit
    g_conf_password=root
    g_conf_p12_password=root
    ```

    - `g_conf_name`：证书管理系统拥有者名称
    - `g_conf_domain_suffix`：证书域名后缀，也决定后续可以生成的证书域名
    - `g_conf_country_name`：证书拥有者所在国家
    - `g_conf_state_or_province_name`：证书拥有者所在州或省或地区
    - `g_conf_locality_name`：证书拥有者所在城市或地区
    - `g_conf_organization_name`：证书拥有者所属组织
    - `g_conf_organization_unit_name`：证书拥有者所属组织单元
    - `g_conf_password`：CA密钥的密码
    - `g_conf_p12_password`：p12证书文件的密码

2. 克隆仓库到Linux主机上

    ```bash
    git clone https://github.com/Homqyy/certm.git
    ```

3. 构建并安装“Certm”：

    ```bash
    ./build.sh -i
    ```

4. 安装成功后，就可以通过下面命令进入到虚拟环境中：

    ```bash
    source ./bin/activate.sh
    ```

5. 进入虚拟环境后，就可以使用`certm-*`工具集了，比如：

    ```bash
    certm-mkcert example
    ```

6. 使用完毕后可以通过下面命令退出虚拟环境：

    ```bash
    deactivate
    ```

### 虚拟环境

虚拟环境的目的有两个：

1. 隔离不同版本的或者不同的 certm 环境
2. 避免污染系统环境

比如，可以在同一台机器上安装多个 certm 环境，当要使用的时候，只需要进入到对应的虚拟环境中即可。虚拟环境命令如下：

```bash
Usage: source ./bin/activate.sh [options]

Options:
  -h, --help                  Show this help message and exit
  -n, --name  <venv name>     Set the name of the virtual environment
```

- `-n/--name`：虚拟环境的名称，默认是根目录名称，比如`certm`。

进入虚拟环境的命令如下所示：

```bash
source ./bin/activate.sh -n certm-1
```

- 上述命令将会进入到`certm-1`虚拟环境中，此时命令行提示符会变成如下所示类似：

    ```text
    (certm-1) [admin@cloud-host certm]$
    ```

    - 其中，`certm-1`为虚拟环境名称

- 一旦设置了虚拟环境名称，就会被记住，下次进入虚拟环境时，就不需要再指定虚拟环境名称了，比如：

    ```bash
    source ./bin/activate.sh
    ```

### certm-mkcert

生成证书工具；生成的证书会放到`output/clients`和`output/servers`目录中，这取决于生成的是客户端证书还是服务器证书。并且在其中还会有子目录`gm`和`rsa`，分别存放GM证书和RSA证书。

使用方法：

```bash
Usage: certm-mkcert [OPTIONS] <domain_name>
Options:
  -b, --begin <DATE>                      Begin date, default is now
  -d, --debug                             Enable debug mode
  -e, --end   <DATE>                      End date, default is 1095 days
  -g, --gm                                Enable gm (deprecated, use "-t SM2" instead)
  -h, --help                              Show help
  -k, --key <PRIVATE_KEY_FILE>            Private key file. If specified of CSR file(-r), will use this key file
  -r, --request <CSR_FILE>                CSR file. If specified, will make certificate from CSR file
  -s, --server                            Server certificate, default is client
  -t, --type  <rsa | ecdsa | sm2>         Certificate Key type, default is 'rsa', 

DATE: format is YYYYMMDDHHMMSSZ, such as 20201027120000Z
```

- `domain_name`：证书域名，可以是二级域名，也可以是三级域名，它会自动跟域名后缀`g_conf_domain_suffix`拼接成完整的域名，比如`example`会拼接成`example.example.cn`。
- `-b/--begin`：证书生效时间，默认是当前时间
- `-d/--debug`：是否开启调试模式，开启后会打印脚本执行的过程
- `-e/--end`：证书失效时间，默认是1095天后
- `-g/--gm`：是否生成GM证书（SM2证书），该选项已经废弃，使用`-t/--type sm2`代替
- `-h/--help`：显示帮助信息
- `-k/--key <PRIVATE_KEY_FILE>`：私钥文件；如果使用 CSR 文件生成证书，则需要指定私钥文件，否则会自动生成私钥文件：
    - 这里的私钥文件时PEM格式
    - 应该与`-t/--type`指定的证书类型一致
    - 应该与`-r/--request`指定的CSR文件中的私钥一致
- `-r/--request <CSR_FILE>`：CSR 文件；如果指定了 CSR 文件，则会用 CSR 文件生成证书
- `-s/--server`：是否生成服务器证书，默认是客户端证书
- `-t/--type`：证书类型，支持RSA、ECDSA和SM2，默认是RSA

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
Usage: certm-revoke [OPTIONS] <domain_name>
Options:
  -g, --gm                        GM certificate(deprecated, use "-t sm2" instead)
  -h, --help                      Show help
  -s, --server                    Server certificate, default is client
  -t, --type <rsa | ecdsa | sm2>  Certificate Key type, default is 'rsa'
```

- `domain_name`：证书名称，与`certm-mkcert`命令生成证书时的名称一致
- `-g/--gm`：是否生成GM证书（SM2证书），该选项已经废弃，使用`-t/--type sm2`代替
- `-s/--server`：是否是服务器证书，默认是客户端证书
- `-t/--type`：证书类型，支持RSA、ECDSA和SM2，默认是RSA

### others

- certm-openssl
- certm-cdroot
- certm-cdclients
- certm-cdservers
- certm-cdca
- certm-lsclients
- certm-lsservers
- certm-lsca

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