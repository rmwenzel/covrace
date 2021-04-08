# US Racial segregation and COVID-19 testing and vaccine site distribution

For now this repo is private, so this page will just be for our use -- we can update when we make it public.

We'll be using AWS for cloud computing. For now we have a simple solution which allows us to run a copy of RStudio on a dedicated EC2 instance running an Ubuntu server. No web app yet!

Since the EC2 instance costs money (about 30 cents/hr) for now let's start and stop as needed. Later we'll make this process a lot easier.

Here's the steps for now:

...

### Start EC2 Instance and Connect

1. Log in to AWS Management Console as an IAM user here:

https://citta.signin.aws.amazon.com/console

2. Select Services -> EC2 -> Instances.
3. Select the EC2 instance "cov-race-test-vacc", then Instance State -> Start Instance.
4. Select Connect -> EC2 Instance Connect.
5. Enter User name: emmanuella
6. Click Connect

This will open a browser tab accessing the terminal/command line in the instance

### Start Rstudio and login

1. Run the following command in the terminal:

```docker run -e USER=your_user_name -e PASSWORD=your_password -dp 8787:8787 -v /home/ubuntu/cov-race-test-vacc:/home/your_user_name/cov-race-test-vacc rocker/tidyverse```

Replacing `your_user_name` and `your_password` with whatever you want to use (for this session). This will get Rstudio running. 

2. Visit ec2-44-242-152-213.us-west-2.compute.amazonaws.com:8787 and login using credentials from last step.

3. Do whatever you'd like to do in RStudio. The results of your work (workspace etc.) will be saved and available next time you start up the instance.

### Stop EC2 instance 

1. Go back to AWS Management Console
2. Select Services -> EC2 -> Instances.
3. Select the EC2 instance "cov-race-test-vacc", then Instance State -> Stop Instance.






