In this terraform i am creating a vpc , security group for web app in private subnet , 2 app servers in different az's  and mutli az rds machine.
the traffic to app servers flow via the alb in the public subnet , to target group behind it .
