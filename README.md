# CertManager

证书生成工具

## 部署和使用

1. 克隆仓库到Linux主机上
2. 执行初始化脚本：

    ```bash
    cd /path/to/certm/init
    
    bash ./init.sh
    ```

    - 生成的证书会输出到屏幕上，可检查一下内容，没问题的话就按`y`

### 生成客户端证书

格式为：

```bash
bash /path/to/certm/init/tools/client.sh <domain_name> [is_gm]
```

比如生成一个centos.local证书（这里的domain_name主要作用于CN上）：

- RSA证书：

    ```bash
    bash /path/to/certm/init/tools/client.sh centos.local
    ```

- 国密证书：

    ```bash
    bash /path/to/certm/init/tools/client.sh gm-centos.local 1
    ```

### 生成服务器证书

