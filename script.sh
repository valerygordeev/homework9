#!/bin/bash

echo "Переключение на суперпользователя"
sudo su
#echo "Установка пакет программ, включая script"
#yum install util-linux -y
echo "Переходим в домашний каталог рута"
cd
#echo "Запускаем логирование"
#script -a homework9.log
echo "Создаем файл конфигурации сервиса"
touch /etc/sysconfig/watchlog
cat <<'EOF' >> /etc/sysconfig/watchlog
# Configuration file for my watchlog service
# Place it to /etc/sysconfig
# File and word in that file that we will be monit
WORD="ALERT"
LOG=/var/log/watchlog.log
EOF
echo "Создаем файл конфигурации сервиса и добавим в него слово ALERT"
touch /var/log/watchlog.log
echo "ALERT" > /var/log/watchlog.log
echo "Создаем скрипт, который будет выводить сообщение $ DATE: I found word, Master! в системный журнал"
touch /opt/watchlog.sh
cat <<'EOF'>> /opt/watchlog.sh
#!/bin/bash

WORD=$1
LOG=$2
DATE=`date`

if grep $WORD $LOG &> /dev/null
then
  logger "$DATE: I found word, Master!"
else
  exit 0
fi
EOF
echo "Добавим права для запуска скрипта"
chmod +x /opt/watchlog.sh
echo "Создаем unit для сервиса"
touch /etc/systemd/system/watchlog.service
cat <<'EOF'>> /etc/systemd/system/watchlog.service
[Unit]
Description=My watchlog service
Wants=watchlog.timer

[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/watchlog
ExecStart=/opt/watchlog.sh $WORD $LOG
EOF
echo "Создаем unit для timer"
touch /etc/systemd/system/watchlog.timer
cat <<'EOF'>> /etc/systemd/system/watchlog.timer
[Unit]
Description=Run watchlog script every 30 second

[Timer]
# Run every 30 second
OnUnitActiveSec=30
Unit=watchlog.service
AccuracySec=1us

[Install]
WantedBy=multi-user.target
EOF
echo "Запускаем службы"
systemctl start watchlog.service
systemctl status watchlog.service
systemctl start watchlog.timer
systemctl status watchlog.timer
echo "Отображаем вывод записи системного лога"
timeout -k 10 1m tail -f /var/log/messages

echo "======================================================"
echo "Устанавливаем ПО"
yum install epel-release -y && yum install spawn-fcgi php php-climod_fcgid httpd -y
echo "Разкомментируем 2 последние строки конфигурационного файла"
sed '7,8s/#//' /etc/sysconfig/spawn-fcgi
echo "Создаем юнит"
cat <<'EOF'>> /etc/systemd/system/spawn-fcgi.service
[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target

[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/sysconfig/spawn-fcgi
ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
echo "Запускаем и контролируем юнит"
systemctl start spawn-fcgi
systemctl status spawn-fcgi

echo "======================================================"
echo "Конфигурируем шаблон для запуска нескольких экземплятор сервиса"
sed -i 'd' /usr/lib/systemd/system/httpd.service > /dev/null
cat <<'EOF'>> /usr/lib/systemd/system/httpd.service
[Unit]
Description=The Apache HTTP Server
Wants=httpd-init.service
After=network.target remote-fs.target nss-lookup.target httpd-init.service
Documentation=man:httpd.service(8)

[Service]
Type=notify
Environment=LANG=C
EnvironmentFile=/etc/sysconfig/httpd-%I
ExecStart=/usr/sbin/httpd $OPTIONS -DFOREGROUND
ExecReload=/usr/sbin/httpd $OPTIONS -k graceful
# Send SIGWINCH for graceful stop
KillSignal=SIGWINCH
KillMode=mixed
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
echo "Копируем шаблон в системную директорию под именами для запуска нескольких экземпляров сервиса"
cp /usr/lib/systemd/system/httpd.service /etc/systemd/system/httpd@first.service 
cp /usr/lib/systemd/system/httpd.service /etc/systemd/system/httpd@second.service
echo "В самим файлах окружения задается опция для запуска веб-сервера с необходимым конфигурационным файлом"
echo "OPTIONS=-f conf/first.conf" > /etc/sysconfig/httpd-first
echo "OPTIONS=-f conf/second.conf" > /etc/sysconfig/httpd-second
echo "Копирует конфигурационный файл для запуска нескольких экземпляров сервиса"     
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/first.conf
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/second.conf 
echo "Изменяем конфигурационный файл second.conf"
sed -i 's/Listen 80/Listen 8080/' /etc/httpd/conf/second.conf > /dev/null
echo "PidFile /var/run/httpd-second.pid" >> /etc/httpd/conf/second.conf 
echo "Запускаем сервисы"
systemctl start httpd@first.service
systemctl start httpd@second.service
echo "Проверяем их статусы и какие порты слушаются"
systemctl status httpd@first.service
systemctl status httpd@second.service            
ss -tnulp | grep httpd
#script exit
#exit
