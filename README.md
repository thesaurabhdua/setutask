In this terraform i am creating a vpc , security group for web app and app severs in private subnet , 2 app servers in different az's  and mutli az rds machine.
the traffic to app servers flow via the alb in the public subnet , to target group behind it .
Wep and App instances have docker container running on them on port 80 mapped to host port 80 .

DEPLOYMENT STRATEGY:
Blue green can be done here by creating one more target group for alb.
We can deploy code to new tg , test it then switch traffic to green tg . If any issues we can roll back deployment to blue tg.

ALSO TO FURTHER ENHANCE THE FUNCTIONALITY WE CAN USE ASG FOR BOTH WEB AND APP .
AND A REMOTE S3 BACKEND TO STORE THE STATE.
