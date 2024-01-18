FROM ubuntu:22.04
RUN apt update -y && apt install nginx -y && apt install vim -y
RUN apt install netcat -y
RUN apt install busybox -y
WORKDIR /etc/nginx/conf.d
COPY ./exercise.conf /etc/nginx/conf.d
EXPOSE 80
CMD [ "nginx", "-g", "daemon off;" ]
