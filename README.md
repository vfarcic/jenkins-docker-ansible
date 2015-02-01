This series will try to provide one possible way to develop applications. We'll go through the full applications lifecycle. We'll define high-level requirements and design, use BDD to define executable requirements and develop using TDD. Architecture will be based on Microservices and the whole process will be backed by continuous deployment. Every commit to the repository will be deployed to production if it passed all tests. We'll programm in JavaScript backed by AngularJS and Scala with Spray. Configuration management will be done with Ansible. Microservices and front-end will be built and deployed with Docker. Depending on where this leads us, there will be many other surprised on the way.

This will be an exiting journey that starts with high-level requirements and ends with fully developed application deployed to production.

High Level Requirements
=======================

We are building Books Retailer application. We should have a web site that can be used on any device (desktop, tables and mobiles). Users of that site should be able to list and search for books, see their details and purchase them. Purchase can be done only by registered users. On the other hand, site administrators should be able to add new books and update or remove existing ones.

High Level Design
=================

We'll build our application using Microservices architectural approach. Each service our application needs will be designed, developed, packed and deployed as a separate application. Each microservice will expose RESTful API that front-end, others services and third parties can use. Data will be stored in MongoDB.

Front-end will be decoupled from back-end and communicate with it by sending RESTful JSON requests.

Everything will be packed and deployed as self sufficient Docker containers.

Environments
============

Since we will have several microservices and applications, each of the should have their own development environment. Those environments will be created using Vagrant and Ansible. Further on, we should have an environment with Jenkins that should handle our applications life-cycle from commit to deployment to production. Finally, there should be at least one environment for testing and one that should be used for production. All in all, there will be:

* Development environments for each microservice and/or application.
* One CD environment
* Production environment

We'll skip the first set of development environments since they will be done for each microservice and application separately.
 
CD Environment
--------------

We'll set up Jenkins environment using Vagrant and Ansible. Vagrant will create a VM with Ubuntu and run the [bootstrap.sh](https://github.com/vfarcic/cd-workshop/blob/master/bootstrap.sh) script. The only purpose of that script is to install Ansible. Once that is done, Ansible will make sure that Docker is installed and Jenkins process is running.

As everything else in this article, Jenkins itself is packed as a [Docker container](https://registry.hub.docker.com/u/vfarcic/jenkins/dockerfile/) and deployed with Ansible. Please consult the [Continuous Deployment: Implementation with Ansible and Docker](http://technologyconversations.com/2014/12/29/continuous-deployment-implementation-with-ansible-and-docker/) article for more info.

```bash
vagrant up cd
```

This might take a while when run for the first time (each consecutive run will be much faster) so this might be a good time to go through the setup while waiting for the creation of VM to finish. 

Two key lines in the Vagrantfile are:

```bash
config.vm.provision "shell", path: "bootstrap.sh"
...
prod.vm.provision :shell, inline: 'ansible-playbook /vagrant/ansible/cd.yml -c local'
```

First one runs the [bootstrap.sh](https://github.com/vfarcic/cd-workshop/blob/master/bootstrap.sh) script that install Ansible. We could use the [Vagrant Ansible Provisioner](https://docs.vagrantup.com/v2/provisioning/ansible.html) but that would require Ansible to be installed on the host machine. That is unnecessary dependency especially for Windows users who would have a hard time to setup Ansible.

Once [bootstrap.sh](https://github.com/vfarcic/cd-workshop/blob/master/bootstrap.sh) is finished, Ansible playbook [cd.yml](https://github.com/vfarcic/cd-workshop/blob/master/ansible/cd.yml) is run.
 
```bash
- hosts: localhost
  remote_user: vagrant
  sudo: yes
  roles:
    - java
    - docker
    - registry
    - jenkins
```

It will run roles java, docker, registry and jenkins. Java is the Jenkins dependency required for running slaves. Docker is needed for building and running containers. All the rest will run as Docker containers. There will be no other dependency, package or application that will be installed directly. Registry role runs Docker registry. Instead of using public one on hub.docker.com, we'll push all our containers to the private Docker registry running on port 5000. Finally, role jenkins is run. This one might require a bit more explanation. Here's the list of tasks in the jenkins role.

```bash
- name: Directories are present
  file:
    path="{{ item }}"
    state=directory
    mode=777
  with_items: directories
  tags: [jenkins]

- name: Config files are present
  copy:
    src='{{ item }}'
    dest='{{ jenkins_directory }}/{{ item }}'
  with_items: configs
  tags: [jenkins]

- name: Plugins are present
  get_url:
    url='https://updates.jenkins-ci.org/{{ item }}'
    dest='{{ jenkins_directory }}/plugins'
  with_items: plugins
  tags: [jenkins]

- name: Job directories are present
  file:
    path='{{ jenkins_directory }}/jobs/{{ item }}'
    state=directory
  with_items: jobs
  tags: [jenkins]

- name: Job configs are present
  template:
    src=job.xml.j2
    dest='{{ jenkins_directory }}/jobs/{{ item }}/config.xml'
    backup=yes
  with_items: jobs
  tags: [jenkins]

- name: Container is running
  docker:
    name=jenkins
    image=vfarcic/jenkins
    ports=8080:8080
    volumes=/data/jenkins:/jenkins
  tags: [jenkins]

- name: Reload
  uri:
    url=http://localhost:8080/reload
    method=POST
    status_code=302
  tags: [jenkins]
```

First we create directories where Jenkins plugins and slaves will reside. In order to speed up building containers, we're also creating the directory where ivy files (used by SBT) will be stored on host. That way containers will not need to download all dependencies every time we build docker containers.

Once directories are created, we copy Jenkins configuration files and download few plugins.

Next are Jenkins jobs. Since all jobs are going to do the same thing, we have one template that will be used to create as many jobs as we need. Jobs will do following:

* Clone the code repository from GitHub
* Run following commands (example with books-service created in the [Microservices Development with Scala, Spray, Mongodb, Docker and Ansible](http://technologyconversations.com/2015/01/26/microservices-development-with-scala-spray-mongodb-docker-and-ansible/) article):
** sudo docker build -t localhost:5000/books-service-tests docker/tests/
** sudo docker push localhost:5000/books-service-tests
** sudo docker run -t --rm \
     -v $PWD:/source \
     -v /data/.ivy2:/root/.ivy2/cache \
     localhost:5000/books-service-tests
** sudo docker build -t localhost:5000/books-service .
** sudo docker push localhost:5000/books-service

First we build the test container and push it to the private registry. Then we run tests. If previous command didn't fail, we'll build the books-service container and push it to the private registry. From here on, books-service is tested, built and ready to be deployed.

Before Docker, all my Jenkins servers ended up with a huge number of jobs. Many of them were different due to different architectures of software they we building. Managing a log of different jobs easily becomes very tiring and prone to errors. And it's not only jobs that become complicated very fast. Managing slaves and dependencies they need to have often requires a lot of time.

With Docker comes simplicity. If we can assume that each project will have its own tests and application containers, all jobs can do the same thing. Build the test container and run it. If nothing fails, build the application container and deploy it. All projects can be exactly the same if we can assume that each of them has their own docker files. Another advantage is that there's nothing to be installed on servers (besides Docker). All they need is Docker that will run containers we tell him to run.

Now we can open [http://localhost:8080](http://localhost:8080) and use Jenkins.

TODO: Blue-Green Deployment
TODO: Write about reasons behind this setup
TODO: Explain that GitHub hook is not created
TODO: Double check that credentials are working
TODO: Mention complete source code.
TODO: Write summary
TODO: ssh-keygen & ssh-copy-id
TODO: Walkthrough Jenkins UI

Production Environment
----------------------

In order to simulate closer to reality situation, production environment will be a separate VM. At the moment we don't need anything installed on that VM. Later on, Jenkins will run Ansible that will make sure that the server is setup correctly before deploying the application. We'll create this environment in the same way as the previous one.

```bash
vagrant up prod
```

Books Microservice
==================

The first piece of code we'll develop, test, build and deploy is the service that will provide RESTful JSON operations related to retrieval and administration of books. The code for this service is already available at [books-service repo](https://github.com/vfarcic/books-service). It is developed using [Scala](http://www.scala-lang.org/) with [Spray](http://spray.io/) and [MongoDB](http://www.mongodb.org/) for data storage. For more information about this service, please consult [Microservices Development with Scala, Spray, MongoDB, Docker and Ansible](http://technologyconversations.com/2015/01/26/microservices-development-with-scala-spray-mongodb-docker-and-ansible/) article.

What we want to do with Jenkins is following:

* Checkout the code from the repository on every commit
* Run tests that do not require the application to be deployed (static analysis, unit tests)
* Build the assembly
* Build the application as a Docker container
* Push the container to the registry
* Deploy the application while maintaining the previous version operational and available for general use
* Test the deployed application (functional, integration, stress, etc)
* Redirect the public traffic from the previous version to the new one.
* Stop the previous version from running

If we do this, we'll have the full lifecycle from commit to production deployment without any manual action in between. Let's start!

Checkout the code from the repository on every commit
-----------------------------------------------------

Normally this would require various installations on the Jenkins or a slave machine. If we are building different applications we would need to have everything needed for those builds installed (JDKs, Gradle, Maven, Python, NodeJS, DBs, etc). Managing dependencies needed for builds and tests execution can easily become overwhelming. On top of that, number of Jenkins jobs can easily become huge and unmanageable.

With docker this can easily be simplified. Each project could have two Dockerfiles, one for testing and one for building the container with the actual application. All dependencies and scripts would be inside the container.