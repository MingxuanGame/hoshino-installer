#!/bin/bash
set -e

# ensure amd64
if [ $(uname -m) != "x86_64" ]; then
    echo "Sorry, the architecture of your device is not supported yet."
    exit
fi

# ensure run as root
if [ $EUID -ne 0 ]; then
    echo "Please run as root"
    exit
fi

echo "
yobot-gocqhttp installer script
What will it do:
1. install docker
2. run hoshinobot in docker
3. run yobot in docker
4. run go-cqhttp in docker
After script finished, you need to press 'ctrl-P, ctrl-Q' to detach the container.
此脚本执行结束并登录后，你需要按下【ctrl-P，ctrl-Q】连续组合键以挂起容器
"

read -p "请输入作为机器人的QQ号：" qqid
read -p "请输入作为机器人的QQ密码：" qqpassword
export qqid
export qqpassword

echo "开始安装，请等待"

if [ -x "$(command -v docker)" ]; then
    echo "docker found, skip installation"
else
    echo "installing docker"
    wget "https://get.docker.com" -O docker-installer.sh
    sh docker-installer.sh --mirror Aliyun
    rm docker-installer.sh
fi

access_token="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)"

docker pull pcrbot/hoshinobot
docker pull pcrbot/gocqhttp:1.0.0-beta8-fix2
docker pull yobot/yobot:pypy

docker network create qqbot || true

mkdir yobot_data gocqhttp_data

docker run --rm -v ${PWD}:/tmp/Hoshino pcrbot/hoshinobot mv /HoshinoBot/ /tmp/Hoshino/Hoshino
echo "HOST = '0.0.0.0'">>Hoshino/hoshino/config/__bot__.py
echo "ACCESS_TOKEN = '${access_token}'">>Hoshino/hoshino/config/__bot__.py


echo "
account:
  uin: ${qqid}
  password: '${qqpassword}'
  encrypt: false
  status: 0      # 在线状态 请参考 https://docs.go-cqhttp.org/guide/config.html#在线状态
  relogin:
    delay: 3
    interval: 3
    max-times: 0
  use-sso-address: true
heartbeat:
  interval: 5
message:
  post-format: string
  ignore-invalid-cqcode: false
  force-fragment: false
  fix-url: false
  proxy-rewrite: ''
  report-self-message: false
  remove-reply-at: false
  extra-reply-data: false
  skip-mime-scan: false
output:
  log-level: warn
  log-aging: 15
  log-force-new: true
  log-colorful: true
  debug: false
default-middlewares: &default
  access-token: '${access_token}'
  filter: ''
  rate-limit:
    enabled: false
    frequency: 1
    bucket: 1
database:
  leveldb:
    enable: true
  cache:
    image: data/image.db
    video: data/video.db
servers:
  - ws-reverse:
      universal: ws://hoshino:8080/ws/
      reconnect-interval: 3000
      middlewares:
        <<: *default
">gocqhttp_data/config.yml

echo "starting hoshinobot"
docker run -d \
           -v ${PWD}/Hoshino:/HoshinoBot \
           --name hoshino \
           --network qqbot \
           pcrbot/hoshinobot

echo "starting yobot"
docker run -d \
           -v ${PWD}/yobot_data:/yobot/yobot_data \
           -e YOBOT_ACCESS_TOKEN="${access_token}" \
           -p 9222:9222 \
           --name yobot \
           --network qqbot \
           yobot/yobot:pypy

echo "starting gocqhttp"
docker run -it \
           -v ${PWD}/gocqhttp_data:/data \
           -v ${PWD}/Hoshino:/HoshinoBot \
           --name gocqhttp \
           --network qqbot \
           pcrbot/gocqhttp:1.0.0-beta8-fix2
