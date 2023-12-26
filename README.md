# homework9
```
Написать сервис, который будет раз в 30 секунд мониторить лог на
предмет наличия ключевого слова. Файл и слово должны задаваться в
/etc/sysconfig

1. Создаем файл конфигурации сервиса
     vi /etc/sysconfig/watchlog
        # Configuration file for my watchlog service
        # Place it to /etc/sysconfig
        # File and word in that file that we will be monit
        WORD="ALERT"
        LOG=/var/log/watchlog.log
2. Создаем файл конфигурации сервиса и добавим в него слово ALERT
      vi /var/log/watchlog.log
        ALERT
3. Создаем скрипт, который будет выводить сообщение "$DATE: I found word, Master!" в системный журнал
      vi /opt/watchlog.sh      
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
4.  Добавим права для запуска скрипта
      chmod +x /opt/watchlog.sh  
5.  Создаем unit для сервиса 
      vi /etc/systemd/system/watchlog.service
        [Unit]
        Description=My watchlog service
        Wants=watchlog.timer

        [Service]
        Type=oneshot
        EnvironmentFile=/etc/sysconfig/watchlog
        ExecStart=/opt/watchlog.sh $WORD $LOG
5.  Создаем unit для timer                                  
      vi /etc/systemd/system/watchlog.timer
        [Unit]
        Description=Run watchlog script every 30 second

        [Timer]
        # Run every 30 second
        OnUnitActiveSec=30
        Unit=watchlog.service
        AccuracySec=1us

        [Install]
        WantedBy=multi-user.target
        
        Параметр AccuracySec=1us использован для точного запуска таймера
6.  Запускаем таймер
       systemctl start watchlog.timer
7.  Отображаем вывод записи системного лога
       tail -f /var/log/messages      


Из epel установить spawn-fcgi и переписать init-скрипт на unit-файл. Имя
сервиса должно также называться.

1.  Устанавливаем ПО
      yum install epel-release -y && yum install spawn-fcgi php php-climod_fcgid httpd -y
2.  Разкомментируем 2 последние строки конфигурационного файла
      vi /etc/sysconfig/spawn-fcgi
        # You must set some working options before the "spawn-fcgi" service will work.
        # If SOCKET points to a file, then this file is cleaned up by the init script.
        #
        # See spawn-fcgi(1) for all possible options.
        #
        # Example :
        SOCKET=/var/run/php-fcgi.sock
        OPTIONS="-u apache -g apache -s $SOCKET -S -M 0600 -C 32 -F 1 -- /usr/bin/php-cgi"
3.  Создаем юнит
      vi /etc/systemd/system/spawn-fcgi.service
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
4.  Запускаем и контролируем юнит
      systemctl start spawn-fcgi
      systemctl status spawn-fcgi
      
 Дополнить юнит-файл apache httpd возможностью запустить несколько
инстансов сервера с разными конфигами

1.  Конфигурируем шаблон для запуска нескольких экземплятор сервиса
      vi /usr/lib/systemd/system/httpd.service
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
        
2.  Копируем шаблон в системную директорию под именами для запуска нескольких экземпляров сервиса
        cp /usr/lib/systemd/system/httpd.service /etc/systemd/system/httpd@first.service 
        cp /usr/lib/systemd/system/httpd.service /etc/systemd/system/httpd@second.service
        
3.  В самим файлах окружения задается опция для запуска веб-сервера с необходимым конфигурационным файлом:      
      vi /etc/sysconfig/httpd-first
        OPTIONS=-f conf/first.conf  
        
      vi /etc/sysconfig/httpd-second
        OPTIONS=-f conf/second.conf
        
4.  Копирует конфигурационный файл для запуска нескольких экземпляров сервиса
      cp /etc/httpd/conf/httpd.conf first.conf
      cp /etc/httpd/conf/httpd.conf second.conf 

5.  Изменяем конфигурационный файл second.conf     
      vi /etc/httpd/conf/second.conf 
        Меняем Listen 80 на Listen8080
        Добавляем строку PidFile /var/run/httpd-second.pid
       
6.  Запускаем сервисы:
      systemctl start httpd@first.service
      systemctl start httpd@second.service
      
7.  Проверяем их статусы и какие порты слушаются:
      systemctl status httpd@first.service
      systemctl status httpd@second.service            
      ss -tnulp | grep httpd
```
