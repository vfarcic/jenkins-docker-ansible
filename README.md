This article tries to provide one possible way to setup the Continuous Integration, Delivery or Deployment pipeline. We'll use [Jenkins](http://jenkins-ci.org/), [Docker](https://www.docker.com/), [Ansible](http://www.ansible.com) and [Vagrant](https://www.vagrantup.com/) to setup two servers. One will be used as a Jenkins server and the other as an imitation of production servers. First one will be used to checkout, test and build applications while the other for deployment and post-deployment tests.

CI/CD Environment
=================

We'll set up Jenkins environment using Vagrant and Ansible. Vagrant will create a VM with Ubuntu and run the [bootstrap.sh](https://github.com/vfarcic/jenkins-docker-ansible/blob/master/bootstrap.sh) script. The only purpose of that script is to install Ansible. Once that is done, Ansible will make sure that Docker is installed and Jenkins process is running.

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

First one runs the [bootstrap.sh](https://github.com/vfarcic/jenkins-docker-ansible/blob/master/bootstrap.sh) script that install Ansible. We could use the [Vagrant Ansible Provisioner](https://docs.vagrantup.com/v2/provisioning/ansible.html) but that would require Ansible to be installed on the host machine. That is unnecessary dependency especially for Windows users who would have a hard time to setup Ansible.

Once [bootstrap.sh](https://github.com/vfarcic/jenkins-docker-ansible/blob/master/bootstrap.sh) is finished, Ansible playbook [cd.yml](https://github.com/vfarcic/jenkins-docker-ansible/blob/master/ansible/cd.yml) is run.
 
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

It will run roles java, docker, registry and jenkins. Java is the Jenkins dependency required for running slaves. Docker is needed for building and running containers. All the rest will run as Docker containers. There will be no other dependency, package or application that will be installed directly. Registry role runs Docker registry. Instead of using public one on hub.docker.com, we'll push all our containers to the private registry running on port 5000. Finally, jenkins role is run. This one might require a bit more explanation.

Here's the list of tasks in the jenkins role.

```bash
- name: Directories are present
  file: path="{{ item }}" state=directory
  with_items: directories

- name: Config files are present
  copy: src='{{ item }}' dest='{{ jenkins_directory }}/{{ item }}'
  with_items: configs

- name: Plugins are present
  get_url: url='https://updates.jenkins-ci.org/{{ item }}' dest='{{ jenkins_directory }}/plugins'
  with_items: plugins

- name: Build job directories are present
  file: path='{{ jenkins_directory }}/jobs/{{ item }}' state=directory
  with_items: jobs

- name: Build jobs are present
  template: src=build.xml.j2 dest='{{ jenkins_directory }}/jobs/{{ item }}/config.xml' backup=yes
  with_items: jobs

- name: Deployment job directories are present
  file: path='{{ jenkins_directory }}/jobs/{{ item }}-deployment' state=directory
  with_items: jobs

- name: Deployment jobs are present
  template: src=deployment.xml.j2 dest='{{ jenkins_directory }}/jobs/{{ item }}-deployment/config.xml' backup=yes
  with_items: jobs

- name: Container is running
  docker: name=jenkins image=vfarcic/jenkins ports=8080:8080 volumes=/data/jenkins:/jenkins

- name: Reload
  uri: url=http://localhost:8080/reload method=POST status_code=302
  ignore_errors: yes
```

First we create directories where Jenkins plugins and slaves will reside. In order to speed up building containers, we're also creating the directory where ivy files (used by SBT) will be stored on host. That way containers will not need to download all dependencies every time we build docker containers.

Once directories are created, we copy Jenkins configuration files and download few plugins.

Next are Jenkins jobs. Since all jobs are going to do the same thing, we have two templates that will be used to create as many jobs as we need.

Finally, once Jenkins job files are in the server, we are making sure that Jenkins container is up and running.

Full source code with Ansible Jenkins role can be found in the [jenkins-docker-ansible](https://github.com/vfarcic/jenkins-docker-ansible/tree/master/ansible/roles/jenkins) repository.

Let's go back to Jenkins job templates. One template is for building and the other one for deployment. Build jobs will clone the code repository from GitHub and run following commands (example with books-service created in the [Microservices Development with Scala, Spray, Mongodb, Docker and Ansible](http://technologyconversations.com/2015/01/26/microservices-development-with-scala-spray-mongodb-docker-and-ansible/) article.

```bash
sudo docker build -t 192.168.50.91:5000/books-service-tests docker/tests/
sudo docker push 192.168.50.91:5000/books-service-tests
sudo docker run -t --rm \
  -v $PWD:/source \
  -v /data/.ivy2:/root/.ivy2/cache \
  192.168.50.91:5000/books-service-tests
sudo docker build -t 192.168.50.91:5000/books-service .
sudo docker push 192.168.50.91:5000/books-service
```

First we build the test container and push it to the private registry. Then we run tests. If previous command didn't fail, we'll build the books-service container and push it to the private registry. From here on, books-service is tested, built and ready to be deployed.

Before Docker, all my Jenkins servers ended up with a huge number of jobs. Many of them were different due to variety of architectures of software they were building. Managing a lot of different jobs easily becomes very tiring and prone to errors. And it's not only jobs that become complicated very fast. Managing slaves and dependencies they need to have often requires a lot of time.

With Docker comes simplicity. If we can assume that each project will have its own tests and application containers. If that's the case, all jobs can do the same thing. Build the test container and run it. If nothing fails, build the application container and push it to the registry. Finally, deploy it. All projects can be exactly the same if we can assume that each of them have their own docker files. Another advantage is that there's nothing to be installed on servers (besides Docker). All they need is Docker that will run containers we tell them to run.

Unlike build jobs that are always the same (build with the specification from Dockerfile), deployments tend to get a bit more complicated. Even though applications are immutable and packed in containers, there are still few configuration files, environment variables and/or volumes to be set. That's where Ansible comes handy. We can have every deployment job in Jenkins the same with only name of the Ansible playbook differing. Deployment jobs simply run Ansible role that corresponds to the application we're deploying. It's still fairly simple in most cases. The difference when compared to deploying applications without Docker is huge. While with Docker we need to think only about data (application and all dependencies are packed inside containers), without it we would need not only to think what to install, what to update and how those changes might affect the rest of applications running on the same server or VM. That's one of the reasons why companies tend not to change their technology stack and, for example, still stick with Java 5 (or worse).

As example, books-service tasks are listed below.

```bash
- name: Directory is present
  file:
    path=/data/books-service/db
    state=directory

- name: Container is running
  docker:
    name=books-service
    image=192.168.50.91:5000/books-service
    ports=9001:8080
    volumes=/data/books-service/db:/data/db
```

Now we can open [http://localhost:8080](http://localhost:8080) and (almost) use Jenkins. Ansible tasks did not create credentials so we'll have to do that manually.

* Click "Manage Jenkins" > "Manage Nodes" > "CD" > "Configure".
* Click "Add" button in the "Credentials" Section.
* Type "vagrant" as both username and password and click the "Add" button.
* Select the newly created key int the "Credentials" section.
* Click the "Save" and, finally, the "Launch slave agent" buttons

This could probably be automated as well but, for security reasons I prefer doing this step manually.

Now the CD slave is launched. It's pointing to the CD VM we created and will be used for all our jobs (event when deployed should be done on a separate machine).

We are ready to run the books-service job that was explained earlier. From the Jenkins home page, click "books-service" link and then "Build Now". Progress can be seen in the "Build History" section. "Console Output" inside the build (in this case #1) can be used to see logs. Building Docker containers for the first time can take some time. Once this job is finished it will run the "books-service-deployment". However, we still don't have the production environment VM and the Ansible playbook run by the Jenkins job will fail to connect to it. We'll get back to this soon.
 
Major advantages to this kind of setup is that there is no need to install anything besides Docker on the CD server since everything is run through containers. There will be no headache provoked by installations of all kinds of libraries and frameworks required for compilation and execution of tests. There will be no conflicts between different versions of the same dependency. Finally, Jenkins jobs are going to be very simple since all the logic resides in Docker files in the repositories of applications that should be built, tested and deployed. In other words, simple and painless setup that will be easy to maintain no matter how many projects/applications Jenkins will need to manage.

If naming conventions are used (as in this example), creating new jobs is very easy. All there is to be done is to add new variable to the Ansible configuration file ansible/roles/jenkins/defaults/main.yml and run **vagrant provision cd** or directly **ansible-playbook /vagrant/ansible/prod.yml -c local** from the CD VM.

Here's an example of jobs variable:

```bash
jobs:
  - books-service
  - users-service
  - shopping-cart-service
  - books-ui
```

books-service job is scheduled to pull code from the repository every 5 minutes. This consumes resources and is slow. Better setup is to have a GitHub hook. With it build would be launched almost immediately after each push to the repository. More info can be found in the [GitHub Plugin](https://wiki.jenkins-ci.org/display/JENKINS/GitHub+Plugin#GitHubPlugin-TriggerabuildwhenachangeispushedtoGitHub) page. Similar setup can be done for almost any other type of code repository.

Production Environment
======================

In order to simulate closer to reality situation, production environment will be a separate VM. At the moment we don't need anything installed on that VM. Later on, Jenkins will run Ansible that will make sure that the server is setup correctly for each application we deploy. We'll create this environment in the same way as the previous one.

```bash
vagrant up prod
```

Now, with the production environment up and running, all that's missing is to generate SSH keys and import them to the CD VM. 

```bash
vagrant ssh prod
ssh-keygen # Simply press enter to all questions
exit
vagrant ssh cd
ssh-keygen # Simply press enter to all questions
ssh-copy-id 192.168.50.92 # Password is "vagrant"
```

That's about it. Now we have an production VM where we can deploy applications. We can go back to Jenkins ([http://localhost:8080](http://localhost:8080)) and run the "books-service-deployment" job. When finished, service will be up and running on the port 9001.

Summary
=======

With Docker we can explore new ways to build, test and deploy applications. One of the many benefits of containers is simplicity due to their immutability and self sufficiency. There are no reasons any more to have servers with huge number of packages installed. No more going through the hell of maintaining different versions required by different applications or spinning up new VM for every single application that should be tested or deployed.

But it's not only servers provisioning that got simplified with Docker. Ability to provide Docker file with each application means that Jenkins jobs are greatly simplified. Instead of having tens, hundreds or even thousands of jobs where each of them is specific to the application it is building, testing or deploying, we can simply make all (or most of) Jenkins jobs the same. Build with Dockerfile file, test with Dockerfile and, finally, deploy with Ansible (that also uses Dockerfile).

We didn't touch the subject of post-deployment (functional, integration, stress, etc) tests that are required for successful Continuous Delivery and/or Deployment. We're also missing the way to deploy the application with zero-downtime. Both will be the subject of one of the next articles. We'll continue where we left and explore in more depth what should be done once the application is deployed.

Source code for this article can be found in [jenkins-docker-ansible](https://github.com/vfarcic/jenkins-docker-ansible) repository.

TODO: Change repo URL
TODO: Add pictures