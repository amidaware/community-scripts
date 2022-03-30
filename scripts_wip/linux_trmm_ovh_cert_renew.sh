#!/bin/bash
#########################################
#       Auto renew cert for TRMM        #
#########################################
#       Create: 29/03/2022
#       Version 0.1
#       By Scaff
#########################################

cat << EOF
First step, you need to create an api access from ovh
Go to https://api.ovh.com/createToken/

And configure it like this

GET /domain/zone/
GET /domain/zone/{your.domain}/
GET /domain/zone/{your.domain}/status
GET /domain/zone/{your.domain}/record
GET /domain/zone/{your.domain}/record/*
POST /domain/zone/{your.domain}/record
POST /domain/zone/{your.domain}/refresh
DELETE /domain/zone/{your.domain}/record/*

When done, press Enter to continue
EOF

read apidone


sudo pip install certbot certbot-dns-ovh

echo -ne "Application Key: "
read application_key

echo -ne "Application Secret: "
read application_secret

echo -ne "Consumer Key: "
read consumer_key

echo -ne "Root domain (e.g example.com): "
read domain

echo -ne "E-mail: "
read email

ovhapi="$(cat << EOF
dns_ovh_endpoint = ovh-eu
dns_ovh_application_key = $application_key
dns_ovh_application_secret = $application_secret
dns_ovh_consumer_key = $consumer_key
EOF
)"
echo "${ovhapi}" | sudo tee /root/.ovhapi > /dev/null

sudo chmod 600 /root/.ovhapi

renew="$(cat << EOF
#!/bin/bash
certbot certonly --dns-ovh --dns-ovh-credentials ~/.ovhapi --non-interactive --agree-tos --email $email -d $domain
systemctl restart nginx.service rmm.service celery celerybeat.service nats-api.service nats.service
EOF
)"
echo "${renew}" | sudo tee /home/tactical/renew.sh > /dev/null
sudo chmod +x /home/tactical/renew.sh

sudo crontab -l > cron_bkp
sudo echo "30 4 5 * * /home/tactical/renew.sh >  /dev/null 2>&1" >> cron_bkp
sudo crontab cron_bkp
sudo rm cron_bkp

