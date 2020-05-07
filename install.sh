# Update package manager
sudo yum -y update
# Install semanage command
yum install policycoreutils-python iptables-services
# Allow Nginx to use ports 81 and 8001
sudo semanage port -m -t http_port_t -p tcp 81
sudo semanage port -a -t http_port_t -p tcp 8001
# Allow Nginx to connect the MySQL server and Gunicorn backends
sudo setsebool -P httpd_can_network_connect_db=1
sudo setsebool -P httpd_can_network_connect=1
# Allow Nginx to change system limits
sudo setsebool -P httpd_setrlimit 1
# Add epel repository
sudo yum install -y epel-release
# (Optional) Add Elasticsearch repository
sudo -u root rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
sudo -u root bash -c 'cat << EOF > /etc/yum.repos.d/elasticsearch.repo
[elasticsearch-6.x]
name=Elasticsearch repository for 6.x packages
baseurl=https://artifacts.elastic.co/packages/6.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF'
# Add arquivematica main repository
sudo -u root bash -c 'cat << EOF > /etc/yum.repos.d/archivematica.repo
[archivematica]
name=archivematica
baseurl=https://packages.archivematica.org/1.11.x/centos
gpgcheck=1
gpgkey=https://packages.archivematica.org/1.11.x/key.asc
enabled=1
EOF'
# Add arquivematica extra repository
sudo -u root bash -c 'cat << EOF > /etc/yum.repos.d/archivematica-extras.repo
[archivematica-extras]
name=archivematica-extras
baseurl=https://packages.archivematica.org/1.11.x/centos-extras
gpgcheck=1
gpgkey=https://packages.archivematica.org/1.11.x/key.asc
enabled=1
EOF'
# Install main services used by arquivematica
sudo -u root yum install -y java-1.8.0-openjdk-headless elasticsearch mariadb-server gearmand
# Enable and start services
sudo -u root systemctl enable elasticsearch
sudo -u root systemctl start elasticsearch
sudo -u root systemctl enable mariadb
sudo -u root systemctl start mariadb
sudo -u root systemctl enable gearmand
sudo -u root systemctl start gearmand
# Install Archivematica Storage Service
# First, install the packages
sudo -u root yum install -y python-pip archivematica-storage-service
# Populate the SQLite database, and collect some static files used by django.
sudo -u archivematica bash -c " \
set -a -e -x
source /etc/sysconfig/archivematica-storage-service
cd /usr/lib/archivematica/storage-service
/usr/share/archivematica/virtualenvs/archivematica-storage-service/bin/python manage.py migrate";
sudo -u root systemctl enable archivematica-storage-service
sudo -u root systemctl start archivematica-storage-service
sudo -u root systemctl enable nginx
sudo -u root systemctl start nginx
sudo -u root systemctl enable rngd
sudo -u root systemctl start rngd,
# Archivematica Dashboard and MCP Server
# First, install the packages
sudo -u root yum install -y archivematica-common archivematica-mcp-server archivematica-dashboard
# Create user and mysql database
sudo -H -u root mysql -hlocalhost -uroot -e "DROP DATABASE IF EXISTS MCP; CREATE DATABASE MCP CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
sudo -H -u root mysql -hlocalhost -uroot -e "CREATE USER 'archivematica'@'localhost' IDENTIFIED BY 'demo';"
sudo -H -u root mysql -hlocalhost -uroot -e "GRANT ALL ON MCP.* TO 'archivematica'@'localhost';"
# Run migrations
sudo -u archivematica bash -c " \
set -a -e -x
source /etc/sysconfig/archivematica-dashboard
cd /usr/share/archivematica/dashboard
/usr/share/archivematica/virtualenvs/archivematica-dashboard/bin/python manage.py migrate
";
# Start and enable services
sudo -u root systemctl enable archivematica-mcp-server
sudo -u root systemctl start archivematica-mcp-server
sudo -u root systemctl enable archivematica-dashboard
sudo -u root systemctl start archivematica-dashboard
# Restart Nginx in order to load the dashboard 
sudo -u root systemctl restart nginx
# Archivematica MCP client
# Install the package
sudo -u root yum install -y archivematica-mcp-client
# The MCP Client expects some programs in certain paths
sudo ln -sf /usr/bin/7za /usr/bin/7z
# Tweak ClamAV configuration
sudo -u root sed -i 's/^#TCPSocket/TCPSocket/g' /etc/clamd.d/scan.conf
sudo -u root sed -i 's/^Example//g' /etc/clamd.d/scan.conf
# Indexless mode
sudo sh -c 'echo "ARCHIVEMATICA_DASHBOARD_DASHBOARD_SEARCH_ENABLED=false" >> /etc/sysconfig/archivematica-dashboard'
sudo sh -c 'echo "ARCHIVEMATICA_MCPSERVER_MCPSERVER_SEARCH_ENABLED=false" >> /etc/sysconfig/archivematica-mcp-server'
sudo sh -c 'echo "ARCHIVEMATICA_MCPCLIENT_MCPCLIENT_SEARCH_ENABLED=false" >> /etc/sysconfig/archivematica-mcp-client'
# After that, we can enable and start/restart services
sudo -u root systemctl enable archivematica-mcp-client
sudo -u root systemctl start archivematica-mcp-client
sudo -u root systemctl enable fits-nailgun
sudo -u root systemctl start fits-nailgun
sudo -u root systemctl enable clamd@scan
sudo -u root systemctl start clamd@scan
sudo -u root systemctl restart archivematica-dashboard
sudo -u root systemctl restart archivematica-mcp-server
# Fix firewalld
sudo firewall-cmd --add-port=81/tcp --permanent
sudo firewall-cmd --add-port=8001/tcp --permanent
sudo firewall-cmd --reload
# Create user
sudo -u archivematica bash -c " \
    set -a -e -x
    source /etc/default/archivematica-storage-service || \
        source /etc/sysconfig/archivematica-storage-service \
            || (echo 'Environment file not found'; exit 1)
    cd /usr/lib/archivematica/storage-service
    /usr/share/archivematica/virtualenvs/archivematica-storage-service/bin/python manage.py createsuperuser
  ";
  