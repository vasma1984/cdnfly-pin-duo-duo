# 创建表
mysql -uroot -p@cdnflypass cdn < conf/db.sql

# 预设置管理员账号
hash_pass=`python -c "import bcrypt;print bcrypt.hashpw('cdnfly', bcrypt.gensalt())"`
mysql -uroot -p@cdnflypass cdn -e "insert into user values (null,'admin','admin',null,null,null,10000,0,now(),\"$hash_pass\",1,1);"



