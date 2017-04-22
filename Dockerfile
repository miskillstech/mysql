##### Section 1: Common across all grmtech docker containers. #####
# Q) Why do we keep the following common across all grmtech docker containers?
#  Due to UFS on any physical server the download of ubuntu image/upgrading it and installating telnet ping ifconfig and supervisor will happen only once.
# Q) Why do we use a single RUN statement instead of 4 different?
#  To reduce the numner of aufs layers. Instead of 4 this will create 1 layer. Advantages of reducing 3 aufs layers:
#  1. Faster build
#  2. Easier to debug since the number of layers is less it is easier to understand what is happening.
FROM ubuntu:16.04
RUN apt-get update && \
 apt-get -y upgrade && \
 apt-get install -y telnet inetutils-ping net-tools --no-install-recommends && \
 DEBIAN_FRONTEND=noninteractive apt-get install -y supervisor --no-install-recommends 

# Q) Why am I exporting the environment variable TERM=screen?
#  1. clear gives the error message TERM environment variable not set.
#  2. ls command will not show dirs in a different color.
ENV TERM screen

##### Section 2: Container specific packages #####

# Step1: Install the mysql server
RUN apt -y install wget lsb-release
RUN wget http://repo.mysql.com/mysql-apt-config_0.8.0-1_all.deb && dpkg -i mysql-apt-config_0.8.0-1_all.deb
RUN apt-get update
# If DEBIAN_FRONTEND=noninteractive is not specified then during installation mysql will ask for password
RUN DEBIAN_FRONTEND=noninteractive apt install -y mysql-server

# Step2: Is this really needed?
EXPOSE 3306/tcp

# Step3: Making sure that mysql starts with the config parameters that we want.
COPY etc-mysql-my.cnf /etc/mysql/my.cnf

# Step4: Making sure my.cnf is actually used  by mysqld
# Done by VK on 18th dec 2015 since otherwise the mysqld deamon ignores this file
RUN chmod 444 /etc/mysql/my.cnf

# Step5: Mysql expects to maintain the pid file to know if mysqld is running or not inside /var/run/mysqld
RUN mkdir -p /var/run/mysqld

# Step6: Why? Making sure musql is able to create mysql.pid and mysql.sock file inside /var/run/mysqld
RUN chmod -R 777 /var/run/mysqld

# Step7: Is this required?
RUN chmod -R 777 /var/lib/mysql

# To see the network interfaces on which mysql is listening >netstat -tlpn

CMD ["/usr/bin/supervisord", "-n","-c","/etc/supervisor/supervisord.conf"]

###### Section 3: Troubleshooting notes for this container ########

# Q1) What to do if the initial database does not exist?
# Option 1: Create it
# -------------------
# if the initial mysql db does not exist than it needs to be created using:
# mysqld --initialize
# For mysqld --initialize to work the folder /gt/sc-data-repos/sc-data-mysql should be empty.
# Commands executed by VK on 25th Jan 2017 to create the initial DB
# vk@Vikass-MBP ~> docker exec -ti scsdmysql_server_1 bash
# root@2d374096504a:/# supervisorctl stop mysqld
# root@2d374096504a:/# rm /gt/sc-data-repos/sc-data-mysql/*
# root@2d374096504a:/# mysqld --initialize-insecure --user=mysql
# Why giving  --initialize-insecure? since without this root will have random password and we cannot log in.
# giving --user=mysql since  we want all the files to be owned by the user mysql
# root@2d374096504a:/# ls /gt/sc-data-repos/sc-data-mysql/
# Ref: https://dev.mysql.com/doc/refman/5.7/en/data-directory-initialization-mysqld.html
# Why? This docker container uses the volume statement inside docker-compose.yml to load the mysql data directory from the host server.
# To solve?
# Why are the files owned by root every after giving mysqld --initialize-insecure --user=mysql
#
# Option 2: Check it out from gitlab
# vk@Vikass-MBP /g/sc-data-repos> cd /gt/sc-data-repos/
# vk@Vikass-MBP /g/sc-data-repos> git clone -b  initial-mysql-db-with-root-access https://gitlab.com/savantcare/sc-data-mysql.git

# Q2) Once the initial DB has been created how to connect to it?
# root@6e789c094915:/# mysql   
# root@6e789c094915:/# show databases

# Q3) How to connect to the new DB from phpmyadmin?
# In initialize statemnt the root user is only allowed to connect from localhost to prove this?
# mysql > use mysql
# mysql > select * from user;   -> look at the host column  

# To connect from phpmyadmin container give the following command:
# vk@Vikass-MBP /g/s/sc-wa-phpmyadmin> docker-compose up -d
# vk@Vikass-MBP /g/s/sc-wa-phpmyadmin> docker exec -ti scwaphpmyadmin_server_1 bash
# root@fd849685112d:/# apt install mysql-client
# root@fd849685112d:/# mysql -h scsdmysql_server_1 -u root -> this will refuse connection since root user is only allowed to connect from localhost
# ERROR 1130 (HY000): Host 'scwaphpmyadmin_server_1.emr_default' is not allowed to connect to this MySQL server

# On the scsdmysql_server_1 give the command:
# mysql> CREATE USER 'root'@'%' IDENTIFIED BY 'jaikalima';
# mysql> GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION; -> this is needed so that root@% user can create other users. Without this it cannot see the mysql table.
# now from the scwaphpmyadmin_server_1 give the command:
# > mysql -h scsdmysql_server_1 -u root -p

# Q4) How to create a new user?
# mysql> CREATE USER 'monty'@'%' IDENTIFIED BY 'some_pass';
# ref: http://dev.mysql.com/doc/refman/5.7/en/adding-users.html

# Q5) How to give correct permissions to the data directory?
# data directory needs to be owned by mysql.
# the data directory is only available once the mysql server contaioner is running.
# Hence we cannot give permissions in the dockerfile 
# so the permissions need to be given by supervisord

