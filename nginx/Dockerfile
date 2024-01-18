FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y nginx vim curl

WORKDIR /etc/nginx/conf.d
COPY ./exercise.conf /etc/nginx/conf.d

EXPOSE 80
