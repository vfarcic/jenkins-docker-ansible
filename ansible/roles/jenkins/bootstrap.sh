#!/bin/bash

cp /data/jenkins/config.xml /vagrant/ansible/roles/jenkins/files/.
cp /data/jenkins/credentials.xml /vagrant/ansible/roles/jenkins/files/.
cp /data/jenkins/identity.key.enc /vagrant/ansible/roles/jenkins/files/.
cp /data/jenkins/jobs/books-service/config.xml /vagrant/ansible/roles/jenkins/files/jobs/books-service/.