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

We'll set up Jenkins environment using Vagrant and Ansible. Vagrant will create a VM with Ubuntu and run the bootstrap.sh script. The only purpose of that script is to install Ansible. Once that is done, Ansible will make sure that Docker is installed and Jenkins process is running. As everything else in this article, Jenkins itself is packed as a [Docker container](https://registry.hub.docker.com/u/vfarcic/jenkins/dockerfile/) and deployed with Ansible. Please consult the [Continuous Deployment: Implementation with Ansible and Docker](http://technologyconversations.com/2014/12/29/continuous-deployment-implementation-with-ansible-and-docker/) article for more info. Besides Jenkins, Ansible will install Scala and SBT that will be used to assemble artifacts.

```bash
vagrant up cd
```

Now we can open [http://localhost:8080](http://localhost:8080) and use Jenkins.

TODO: Add /data/jenkins/slaves/cd directory to Ansible
TODO: Convert jobs to templates and copy them to /data/jenkins directory
TODO: Copy files to /data/jenkins directory
TODO: Move Scala & SBT to Docker
TODO: Write about the setup

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
* Deploy the application while maintaining the previous version operational and available for general use
* Test the deployed application (functional, integration, stress, etc)
* Redirect the public traffic from the previous version to the new one.
* Stop the previous version from running

If we do this, we'll have the full lifecycle from commit to production deployment without any manual action in between. Let's start!

Checkout the code from the repository on every commit
-----------------------------------------------------
