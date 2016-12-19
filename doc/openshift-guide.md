# Using 3scale API Gateway on Red Hat OpenShift

This tutorial describes how to use APIcast v2 &ndash; the dockerized 3scale API Gateway that is packaged for easy installation and operation on Red Hat OpenShift V3.

## Tutorial Prerequisites

To follow the tutorial steps below, you'll first need to address the following prerequisites:

### 3scale account configuration

These steps will guide you to finding information you will need later to complete the tutorial steps: your _3scale Admin URL_, your _Provider Key_, and the _Private Base URL_ of your API.

You should have a 3scale API provider account (you can sign up for a free trial <a href="https://www.3scale.net/signup/">here</a>) and have an API configured in the 3scale Admin Portal. If you do not have an API running and configured in your 3scale account, please follow the instructions in our <a href="https://support.3scale.net/guides/quickstart">Quickstart</a> to do so.

Log in to your 3scale Admin Portal with the URL provided to you. It will look something like this: `https://MYDOMAIN-admin.3scale.net`

Navigate to the **Account** tab (top-right). From the **Overview** sub-tab note down your _3scale Provider Key_, referred to in the UI as _API Key_. Later in this tutorial we refer to this as your *THREESCALE_PROVIDER_KEY*.

<img src="https://support.3scale.net/images/screenshots/guides-openshift-provider-key.png" alt="Provider Key">

**Warning**: Keep your _3scale Provider Key_ private. Do not share it with anyone and do not put into code repositories or into any document that may reveal it to others.

In the 3scale Admin Portal you should either have an API of your own running and configured or use the Echo API that was setup by the onboarding wizard. This tutorial will use the Echo API as an example.

Navigate to the **Dashboard > API** tab, if you have more than one API in your account, select the API you want to manage with the API Gateway. Select the **Integration** link at top-left.

If you're setting this up for the first time, you'll need to test the integration to confirm that your private (unmanaged) API is working before proceeding. If you've already configured your API and sent test traffic, feel free to skip this step.

<img src="https://support.3scale.net/images/screenshots/guides-openshift-private-base-url.png" alt="Private base URL">

In the screenshot above, this API is configured to use the 3scale provided Echo API to help you get started. You can use this or configure the _Private Base URL_ to refer to your real API.

Test your private (unmanaged) API is working using this _curl_ command:
    
    curl https://echo-api.3scale.net:443/

You should get a response similar to this:

    {
      "method": "GET",
      "path": "/",
      "args": "",
      "body": "",
      "headers": {
        "HTTP_VERSION": "HTTP/1.1",
        "HTTP_HOST": "echo-api.3scale.net",
        "HTTP_USER_AGENT": "curl/7.43.0",
        "HTTP_ACCEPT": "*/*",
        "HTTP_X_FORWARDED_FOR": "10.1.0.154",
        "HTTP_CONNECTION": "close"
    }

Once you've confirmed that your API is working, scroll down to the bottom of the **Staging** section where you can see a sample _curl_ command:

    curl "https://XXX.staging.apicast.io:443/?user_key=YOUR_USER_KEY"

**Note**: Note down *YOUR_USER_KEY* to use later to authenticate to your managed API.

Next you need to set your API to be a Self-managed Gateway, required to run the gateway on OpenShift. Select the **edit integration settings** link at top-right on the Integration page you are on. Choose **NGINX Self-managed Gateway** and save it by clicking **Update Service**.

You should now see a section **Production: Self-managed Gateway** at the bottom of the Integration page. You need to add a _Public Base URL_ appropriate for this API or Service, that will be the URL of your API gateway. In case you have multiple API services, you will need to set this _Public Base URL_ appropriately for each service. In this example we will use `http://gateway.openshift.demo:80` as _Public Base URL_, but typically it will be something like `https://api.yourdomain.com:443`, on the domain that you manage (`yourdomain.com`).

### Setup OpenShift

There are many ways you can install OpenShift.
- All-In-One Virtual Machine using Vagrant &ndash; https://www.openshift.org/vm
- Using `oc cluster up` command &ndash; https://github.com/openshift/origin/blob/master/docs/cluster_up_down.md (used in this tutorial)
- Using Ansible Playbooks (advanced installation):
  - OpenShift Container Platform 3.3 Installation and Configuration documentation &ndash; https://docs.openshift.com/container-platform/3.3/install_config/index.html
  - For reference architecture guides for OpenShift 3.3 please refer to the following articles: [AWS](https://access.redhat.com/articles/2623521), [Google Cloud Engine](https://access.redhat.com/articles/2751521), [VMware vCenter 6](https://access.redhat.com/articles/2745171)

In this tutorial the OpenShift cluster will be installed using: 
- CentOS 7
- Docker v1.10.3
- Openshift Origin command line interface (CLI) - v1.3.1


1. Install Docker on CentOS

```bash
yum -y update
yum -y install docker docker-registry
```

2. Configure the Docker daemon with an insecure registry parameter of `172.30.0.0/16`
   - Edit the `/etc/sysconfig/docker` file and add or uncomment the following line:
     ```
     INSECURE_REGISTRY='--insecure-registry 172.30.0.0/16'
     ```

   - After editing the config, restart the Docker daemon.
     ```
     $ sudo systemctl restart docker
     ```
3. Download the client tools release
   [openshift-origin-client-tools-VERSION-linux-64bit.tar.gz](https://github.com/openshift/origin/releases)
   and place it in your path.

   > Please be aware that the 'oc cluster' set of commands are only available in the 1.3+ or newer releases.


4. Open a terminal with a user that has permission to run Docker commands and run:
```
$oc cluster up
-- Checking OpenShift client ... OK
-- Checking Docker client ... OK
-- Checking Docker version ... OK
-- Checking for existing OpenShift container ... OK
-- Checking for openshift/origin:v1.3.1 image ... OK
-- Checking Docker daemon configuration ... OK
-- Checking for available ports ... OK
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
-- Checking type of volume mount ...
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
   Using nsenter mounter for OpenShift volumes
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
-- Creating host directories ... OK
-- Finding server IP ...
   Using 10.0.1.163 as the server IP
-- Starting OpenShift container ...
   Creating initial OpenShift configuration
   Starting OpenShift using container 'origin'
   Waiting for API server to start listening
   OpenShift server started
-- Installing registry ... OK
-- Installing router ... OK
-- Importing image streams ... OK
-- Importing templates ... OK
-- Login to server ... OK
-- Creating initial project "myproject" ... OK
-- Server Information ...
   OpenShift server started.
   The server is accessible via web console at:
       https://10.0.1.163:8443

   You are logged in as:
       User:     developer
       Password: developer

   To login as administrator:
       oc login -u system:admin
```

## Tutorial Steps

### Create your 3scale API Gateway using a template

1. Login into OpenShift using the `oc` command from the OpenShift Client tools you downloaded and installed in previous step. The default login credentials are _username = "admin"_ and _password = "admin"_

 <pre><code>oc login https://OPENSHIFT-VM-IP:8443</code></pre>

 **Warning**: You may get a security warning and asked whether you wish to continue with an insecure selection. Enter "yes" to proceed.

 You should see `Login successful.` in the output.

2. Create your project. This example sets the display name as _gateway_
  
 <pre><code>oc new-project "3scalegateway" --display-name="gateway" --description="3scale gateway demo"</code></pre>

 The response should look like this:

 ```Now using project "3scalegateway" on server ""https://10.0.1.163:8443""```

 Ignore the suggested next steps in the text output at the command prompt and proceed to the next step below.

3. Create a new Secret to reference your project by replacing *THREESCALE_PROVIDER_KEY* and MYDOMAIN with yours.
  
 <pre><code>oc secret new-basicauth threescale-portal-endpoint-secret --password=https://THREESCALE_PROVIDER_KEY@MYDOMAIN-admin.3scale.net</code></pre>

 The response should look like this:

 <pre><code>secret/threescale-portal-endpoint-secret</code></pre>

4. Create an application for your 3scale API Gateway from the template:

 <pre><code>oc new-app -f https://github.com/3scale/apicast/releases/download/v2.0.0-rc1/openshift-template.yml</code></pre>

 You should see a message indicating _deploymentconfig_ and _service_ have been successfully created.

### Deploying 3scale API Gateway

1. Open the web console for your OpenShift Origin VM in your browser: https://OPENSHIFT-VM-IP:8443/console/

 **Warning**: You may receive a warning about an untrusted web-site. As this is the Origin VM running on your local machine there are no real risks. Select "Accept the Risks" in the browser and proceed to view the Web console.

 You should see the login screen:
 <img src="https://support.3scale.net/images/screenshots/guides-openshift-login-screen.png" alt="OpenShift Login Screen">

2. Login using your credentials created or obtained in the _Setup OpenShift_ section above.

 You will see a list of projects, including the _"gateway"_ project you created from the command line above.

 <img src="https://support-preview.3scale.net/images/screenshots/guides-openshift-project-list-after.png" alt="Openshift Projects" >

3. Click on _"gateway"_ and you will be shown the _Overview_ tab.

 OpenShift downloads the code for the API Gateway and starts the deployment. You may see the message _Deployment #1 running_ when the deployment is in progress.

 When the build completes, the UI will refresh and show two instances of the API Gateway ( _2 pods_ ) that have been started by OpenShift, as defined in the template.

  <img src="https://support-preview.3scale.net/images/screenshots/guides-openshift-building-threescale-gateway.png" alt="Building the Gateway" >

 Each instance of the 3scale API Gateway, upon starting, downloads the required configuration from 3scale using the settings you provided on the **Integration** page of your 3scale Admin Portal.

 OpenShift will maintain two API Gateway instances and monitor the health of both; any unhealthy API Gateway will automatically be replaced with a new one.

4. In order to allow your API gateways to receive traffic, you'll need to create a route. Start by clicking on **Create Route**.

 <img src="https://support-preview.3scale.net/images/screenshots/guides-openshift-create-route.png" alt="Create Route" >
 
 Enter the same host you set in 3scale above in the section **Public Base URL** (without the _http://_ and without the port) , e.g. `gateway.openshift.demo`, then click the **Create** button.

 <img src="https://support-preview.3scale.net/images/screenshots/guides-openshift-create-route-config.png" alt="Configure Route" >

 Create a new route for every 3scale Service you define.

5. Your API Gateways are now ready to receive traffic.

 OpenShift takes care of load-balancing incoming requests to the route across the two running instances of the API Gateway.

 Test that the API gateway authorizes a valid call to your API, by executing a curl command with your valid *user_key* to the *hostname* that you configured earlier, e.g. :

 <pre><code>curl "http://gateway.openshift.demo/?user_key=YOUR_USER_KEY"</code></pre>

 If you wish to see the logs of the API Gateways you can do so by clicking **Applications > Pods** and then select one of the pods and then selecting **Logs**.

6. Test it does not authorize an invalid call to your API.

 <pre><code>curl "http://gateway.openshift.demo/?user_key=INVALID_KEY"</code></pre>

## Success!

Your API is now protected by two instances of the 3scale API Gateway running on Red Hat OpenShift, following all the configuration that you set-up in the 3scale Admin Portal.

You may wish to now shutdown the OpenShift Origin VM to save resources. 

## Next Steps

Now that you have an API Gateway up and running on your local machine you can:

1. Explore how to configure access policies for your API, and engage developers with a Developer Portal by following the <a href="https://support.3scale.net/guides/quickstart">Quickstart</a>.
2. Whenever you make changes to your API definition in the 3scale Admin Portal &ndash; in particular the 3scale metrics/methods and mapping rules &ndash; you should create a new deployment in OpenShift. This will start new instances that will download and run your new API definition. Then OpenShift will shut down gracefully the previous instances.
3. Run OpenShift V3 on your dedicated datacenter or on your favorite cloud platform and then follow the same instructions to open up your API to the world.
