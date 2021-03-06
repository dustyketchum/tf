# AWS VPC, EKS, ECR, ACM, Github Actions and Flask Demo

```
Create AWS VPCs, EKS IAM roles, EKS clusters and nodes.
Deploy a simple web app using the AWS Load Balancer Controller.
Use Github Actions to rebuild the docker image and push it to ECR whenever there's a commit.
Use Github Actions to perform a kubernetes rolling update to deploy the latest image.

The terraform modules are designed to create multiple VPCs 
and EKS clusters in any region.

Some of the installation instructions and the 
example echoserver deployment are copied from here
https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/deploy/installation/

Next steps / potential enhancements:
- Make a package for eks-kubectl-action to avoid building it every time it is used.
https://github.com/ianbelcher/eks-kubectl-action/issues/9
- Use terraform remote state to resolve subnet issue (see below).
- Use terraform remote state to use one set of EKS IAM 
  roles per environment instead of in each terraform plan.
- Use terraform to create the IAM policies instead of command line.

Expected output (sometimes trunacted output) from each step 
is in comments below each deployment step

```

# One time setup steps

1. ```cd ~/k8s/iam```

2. ```helm repo add eks https://aws.github.io/eks-charts```

"eks" has been added to your repositories

curl -o aws-lbc-iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.2.4/docs/install/iam_policy.json

3. ```aws iam create-policy --policy-name AWSLoadBalancerControllerPolicy --policy-document file://aws-lbc-iam-policy.json```

{\
&nbsp;&nbsp;"Policy": {\
&nbsp;&nbsp;&nbsp;&nbsp;"PolicyName": "AWSLoadBalancerControllerPolicy",\
&nbsp;&nbsp;&nbsp;&nbsp;"PolicyId": "ANPAWxxx",\
&nbsp;&nbsp;&nbsp;&nbsp;"Arn": "arn:aws:iam::xxxxxxxxxxxx:policy/AWSLoadBalancerControllerPolicy",\
...\
&nbsp;&nbsp;}\
}

https://github.com/marketplace/actions/docker-ecr \
https://github.com/marketplace/actions/eks-kubectl \
https://prabhatsharma.in/blog/amazon-eks-iam-authentication-how-to-add-an-iam-user/ 

GithubActionsPolicy is a union of the above policies that allows the user to\
a. view the cluster to run update-kubeconfig\
b. push new images into and pull images from ECR to run docker build and perform deployments upon checkin

4. ```aws iam create-policy --policy-name GithubActionsPolicy --policy-document file://github-actions-iam-policy.json```

{\
&nbsp;&nbsp;"Policy": {\
&nbsp;&nbsp;&nbsp;&nbsp;"PolicyName": "GithubActionsPolicy",\
&nbsp;&nbsp;&nbsp;&nbsp;"PolicyId": "ANPAWxxx",\
&nbsp;&nbsp;&nbsp;&nbsp;"Arn": "arn:aws:iam::xxxxxxxxxxxx:policy/GithubActionsPolicy,\
...\
&nbsp;&nbsp;}\
}


# Create and deploy to the EKS cluster

1. ```cd ~/tf/aws/plans/us-west-2```
2. ```terraform init```

Initializing modules...
...
Terraform has been successfully initialized!

3. ```terraform apply --target=module.vpc-prod```

Apply complete! Resources: xx added, 0 changed, 0 destroyed.

We need to create the VPC and subnets in a separate terraform 
run than the EKS clusters due to this issue
https://discuss.hashicorp.com/t/for-each-value-depends-on-resource-attributes-that-cannot-be-determined-until-apply/6061/2

4. ```terraform apply```

Apply complete! Resources: xx added, 0 changed, 0 destroyed.

5. ```cd ~/k8s/us-west-2/echoserver```

6. ```aws eks --region us-west-2 update-kubeconfig --name usw2-prod-01```

Added new context arn:aws:eks:us-east-2:xxxxxxxxxxxx:cluster/usw2-prod-01 to ~/.kube/config

7. ```eksctl utils associate-iam-oidc-provider --region us-west-2 --cluster usw2-prod-01 --approve```

2021-10-17 06:45:25 [?]  eksctl version 0.69.0\
2021-10-17 06:45:25 [?]  using region us-west-2\
2021-10-17 06:45:25 [?]  will create IAM Open ID Connect provider for cluster "usw2-prod-01" in "us-west-2"\
2021-10-17 06:45:26 [?]  created IAM Open ID Connect provider for cluster "usw2-prod-01" in "us-west-2"

8. ```eksctl create iamserviceaccount --region us-west-2 --cluster=usw2-prod-01 --namespace=kube-system --name=aws-load-balancer-controller --attach-policy-arn=arn:aws:iam::476728484325:policy/AWSLoadBalancerControllerPolicy --override-existing-serviceaccounts --approve```

2021-10-17 06:47:20 [?]  eksctl version 0.69.0\
2021-10-17 06:47:20 [?]  using region us-west-2\
2021-10-17 06:47:22 [?]  1 iamserviceaccount (kube-system/aws-load-balancer-controller) was included (based on the include/exclude rules)\
2021-10-17 06:47:23 [!]  metadata of serviceaccounts that exist in Kubernetes will be updated, as --override-existing-serviceaccounts was set\
2021-10-17 06:47:23 [?]  1 task: { 2 sequential sub-tasks: { create IAM role for serviceaccount "kube-system/aws-load-balancer-controller", create serviceaccount "kube-system/aws-load-balancer-controller" } }\
2021-10-17 06:47:23 [?]  building iamserviceaccount stack "eksctl-prod-01-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"\
2021-10-17 06:47:23 [?]  deploying stack "eksctl-prod-01-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"\
2021-10-17 06:47:23 [?]  waiting for CloudFormation stack "eksctl-prod-01-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"\
2021-10-17 06:48:01 [?]  created serviceaccount "kube-system/aws-load-balancer-controller"

9. ```helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=usw2-prod-01 --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller```

NAME: aws-load-balancer-controller\
LAST DEPLOYED: Sun Oct 17 06:51:08 2021\
NAMESPACE: kube-system\
STATUS: deployed\
REVISION: 1\
TEST SUITE: None\
NOTES:\
AWS Load Balancer controller installed!

10. ```kubectl apply -f echoserver-namespace.yaml```

namespace/echoserver created

11. ```kubectl apply -f echoserver-service.yaml```

service/echoserver created

12. ```kubectl apply -f echoserver-deployment.yaml```

deployment.apps/echoserver created

13. Using the AWS Certificate Manager console, locate the certificate created by terraform for us-west-2.highestpavedroadsinthealps.com\
Select the certificate.\
Under Certificate status, copy the ARN for the certificate into your clipboard.

14. Open echoserver-ingress.yaml in an editor.\
Replace the annotation for ```alb.ingress.kubernetes.io/certificate-arn:``` with the value in your clipboard.\
Save echoserver-ingress.yaml

15. ```kubectl apply -f echoserver-ingress.yaml```

Warning: networking.k8s.io/v1beta1 Ingress is deprecated in v1.19+, unavailable in v1.22+; use networking.k8s.io/v1 Ingress\
ingress.networking.k8s.io/echoserver created

16. The Locate the new ALB in the AWS console and find its DNS record.
    Create or update route53 A or Alias record (ie us-west-2.highestpavedroadsinthealps.com)
    to point dns entry for the new ALB once it is created.

17. Browse to http://us-west-2.highestpavedroadsinthealps.com/ to verify the flask application is running.


# Configure Github Actions

1. Create a new iam user githubactions in the AWS console

Select IAM in Services, then select Users, then select Add Users\
Enter the name githubactions\
Check Access key - Programmatic access\
Select Next: Permissions\
Select Attach existing policies directly\
Check GithubActionsPolicy\
Select Next: Tags\
Select Next: Review\
Select Create User\
Select Secret Access Key Show

2. In another window add your AWS secrets to your Github repository

In your Github repo, select Settings, then Secrets\
Add Repository secrets\
AWS_ACCESS_KEY_ID\
AWS_SECRET_ACCESS_KEY\
Copy and paste the values from the IAM window in the prior step

https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html

3. ```kubectl edit -n kube-system configmap/aws-auth```

Do not add the root user below if you created the eks cluster using root credentials,
this is just an example.\
Add the following after mapRoles to map the githubactions iam user:
```
  mapUsers: |
    - userarn: arn:aws:iam::476728484325:user/githubactions
      username: githubactions
    - userarn: arn:aws:iam::476728484325:root
      username: root
```

configmap/aws-auth edited

4. ```cd ~/k8s/rbac```

https://stackoverflow.com/questions/64284450/what-role-permissions-are-required-to-support-rollout-undo

5. ```kubectl apply -f deploy-cluster-role.yaml```

clusterrole.rbac.authorization.k8s.io/deploy created

6. ```kubectl apply -f deploy-cluster-role-binding.yaml```

clusterrolebinding.rbac.authorization.k8s.io/deploy created

Any github merges should now trigger a rebuild and a redeploy of the echoserver application

Optional admin steps:

7. ```kubectl apply -f admin-cluster-role.yaml```

clusterrole.rbac.authorization.k8s.io/myadmin created

8. ```kubectl apply -f admin-cluster-role-binding.yaml```

clusterrolebinding.rbac.authorization.k8s.io/myadmin created
