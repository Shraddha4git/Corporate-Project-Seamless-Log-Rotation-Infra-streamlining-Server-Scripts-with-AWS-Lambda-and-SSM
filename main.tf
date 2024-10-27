provider "aws" {
  region = "ap-south-1"
}
#provider "local" {}
module "vpc" {
  source = "./modules/vpc"
  bastion_security_group_id = module.bastion.bastion_security_group_id
}

# ALB Module
module "alb" {
  source      = "./modules/alb"
  vpc_id      = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_security_group_id = module.vpc.alb_security_group_id 
}

module "bastion" {
  source = "./modules/bastion"
  public_subnet_ids = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  vpc_id              = module.vpc.vpc_id
  depends_on = [ module.s3 ]
}
# EC2 Module for TG1
module "ec2_tg1" {
  source              = "./modules/ec2_tg1"
  private_subnet_ids  = module.vpc.private_subnet_ids
  public_subnet_ids = module.vpc.public_subnet_ids
  ec2_security_group_id   = module.vpc.ec2_security_group_id
  tg1_arn = module.alb.tg1_arn
  bastion-server-public_ip = module.bastion.bastion-server-public_ip
}

# EC2 Module for TG2
module "ec2_tg2" {
  source              = "./modules/ec2_tg2"
  private_subnet_ids  = module.vpc.private_subnet_ids
  ec2_security_group_id   = module.vpc.ec2_security_group_id
  tg2_arn = module.alb.tg2_arn
  bastion-server-public_ip = module.bastion.bastion-server-public_ip
  iam_instance_profile_name = module.ec2_tg1.iam_instance_profile_name
}

# S3 Module
module "s3" {
  source = "./modules/s3"
}
module "lambda_python_code" {
  source = "./modules/lambda_python_code"
  private_subnet_ids  = module.vpc.private_subnet_ids
  ec2_security_group_id   = module.vpc.ec2_security_group_id
  depends_on = [ module.vpc, module.ec2_tg1, module.ec2_tg2, module.alb]
  listener_arn = module.alb.listener_arn
  tg1_arn = module.alb.tg1_arn
  tg2_arn = module.alb.tg2_arn
  tg1_instance_ids = module.ec2_tg1.tg1_instance_ids
  tg2_instance_ids = module.ec2_tg2.tg2_instance_ids
}