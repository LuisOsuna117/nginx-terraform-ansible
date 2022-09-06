# Nginx-Terraform-Ansible
![license](https://img.shields.io/github/license/LuisOsuna117/nginx-terraform-ansible)

Implementacion de un servidor web Nginx con Auto Scaling en AWS mediante Terraform y Ansible

- [Requisitos](#requisitos)
- [Diagrama](#diagrama)
- [Uso](#uso)
  - [Configuracion con aws-cli](#configuracion-con-aws-cli)
  - [Configuracion con variables de entorno](#configuracion-con-variables-de-entorno)
  - [Estructura del proyecto](#estructura-del-proyecto)
  - [Variables de terraform](#variables-de-terraform)
  - [Funcionalidad](#funcionalidad)
    - [VPC](#vpc)
    - [IAM Role](#iam-role)
    - [Auto Scaling Group](#auto-scaling-group)
    - [ALB](#alb)
    - [Security groups](#security-groups)
  - [Outputs](#outputs)
## Requisitos
* terraform >= 1.1.7
* aws-cli >= 2.4.3

## Diagrama

![Diagrama](https://i.imgur.com/V2RMxPf.jpeg)

## Uso

Primero que todo debemos configurar nuestras credenciales de AWS, puede ser usando aws-cli o guardandolas en variables de entorno.

### Configuracion con aws-cli
```shell
$ aws configure
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: us-west-2
Default output format [None]: json
```

### Configuracion con variables de entorno
```shell
$ export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
$ export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
$ export AWS_DEFAULT_REGION=us-west-2
```

### Estructura del proyecto
El proyecto cuenta con la siguiente estructura:
```console
.
|-- LICENSE
|-- README.md
|-- ansible
|   |-- cloudwatch
|   |   |-- cloudwatch-config.json
|   |   `-- cloudwatch-config.yml
|   `-- nginx
|       |-- index.html
|       |-- nginx_install.yml
|       `-- server.conf
|-- main.tf
|-- output.tf
|-- startup.sh
|-- vars.tf
`-- versions.tf
```
Como podemos ver en la raiz del proyecto se encuentra todo lo relacionado con terraform y aparte hay una carpeta llamada `ansible` en la cual se encuentran 2 playbooks. Uno es para la instalacion y la configuracion de Nginx y el otro es para la configuracion de metricas y logs con CloudWatch sobre las instancias provisionadas. El archivo `startup.sh` se ejecuta cada que se provisiona una nueva instancia y contiene todo el proceso para que ejecute los playbooks de ansible.

### Variables de terraform
El archivo `vars.tf` contiene las variables necesarias para el aprovisionamiento de la infraestructura. Las variables son las siguientes:
```file
variable "vpc_name" {
  description = "Name of the VPC"
  default = "main_vpc"
}

variable "vpc_cidr" {
  description = "CIDR block of the vpc"
  default = "10.0.0.0/16"
}

variable "public_subnets_cidr" {
  type        = list
  description = "CIDR block for Public Subnet"
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "region" {
  description = "Region in which the instances will be launched"
  default = "us-east-1"
}
```
Por defecto ya cuenta con valores pero los mismos pueden ser modificados ya sea al momento de ejecutar `terraform plan` o `terraform apply` asignando un archivo tfvars con -var-file o colocandolas directamente en el comando con -var. De igual manera se pueden utilizar variables de entorno las cuales deben de empezar por `TF_VAR_`, por ejemplo, `TF_VAR_vpc_name`.

Una vez configuradas las variables debemos verificar todos los cambios que realizara en AWS, por lo que para ello ejecutamos `terraform plan` este comando crea un plan de ejecución, que nos permite obtener una vista previa de los cambios que Terraform planea realizar.

### Funcionalidad
En terminos generales la mayoria de la funcionalidad del proyecto esta en `main.tf`, y esta es la descripcion de cada una de sus partes:
#### VPC
```file
data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.4"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs                  = data.aws_availability_zones.available.names
  public_subnets       = var.public_subnets_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
}
```
Esta parte es la encargada de crear la VPC en la que estara desplegado las instancias del autoscaling y el ALB. Esta utilizando las variables de vpc_name y vpc_cidr, las cuales se pueden o no declara para modificar su valor por defecto.
#### IAM Role
```file
resource "aws_iam_role" "cw_role" {
  name = "cwa_role"
  path = "/"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cwa_policy_attach" {
    role = aws_iam_role.cw_role.name
    policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "cwa_profile" {
  name = "cwa_profile"
  role = aws_iam_role.cw_role.name
}
```
Se crea un rol de IAM que se adjunta a las instancias para que el agente de Cloud Watch tenga acceso a las metricas y logs dentro de las instancias.
#### Auto Scaling Group
```file
data "aws_ami" "amazon-linux-2" {
  most_recent = true
  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}
resource "aws_launch_configuration" "nginx" {
  name_prefix     = "nginx-"
  image_id        = data.aws_ami.amazon-linux-2.id
  instance_type   = "t3.micro"
  iam_instance_profile = aws_iam_instance_profile.cwa_profile.name
  user_data       = file("startup.sh")
  security_groups = [aws_security_group.nginx_instance.id]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "nginx" {
  name                 = "nginx"
  min_size             = 1
  max_size             = 3
  desired_capacity     = 1
  launch_configuration = aws_launch_configuration.nginx.name
  vpc_zone_identifier  = module.vpc.public_subnets

  tag {
    key                 = "Name"
    value               = "Nginx with Terraform and Ansible"
    propagate_at_launch = true
  }
}
```
Esta parte busca por la AMI mas reciente de Amazon Linux 2 y se configura el template de lanzamiento del autoscaling group. En el bloque de `aws_launch_configuration` se manda el script `startup.sh` que es el que instala las dependencias para poder ejecutar los playbooks de ansible.
#### ALB
```file
resource "aws_lb" "nginx" {
  name               = "nginx-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.nginx_lb.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_listener" "nginx" {
  load_balancer_arn = aws_lb.nginx.arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx.arn
  }
}

resource "aws_lb_target_group" "nginx" {
  name     = "nginx"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}

resource "aws_autoscaling_attachment" "nginx" {
  autoscaling_group_name = aws_autoscaling_group.nginx.id
  lb_target_group_arn   = aws_lb_target_group.nginx.arn
}
```
Aqui se declara toda la configuracion que va a tener el balanceador de carga, que se configuro para que fuera un Application Load Balancer y que este escuchando al puerto 8080; y finalmente se adjunta el autoscaling group al balanceador.
#### Security groups
```file
resource "aws_security_group" "nginx_instance" {
  name = "nginx-instance"
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx_lb.id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  vpc_id = module.vpc.vpc_id
}

resource "aws_security_group" "nginx_lb" {
  name = "nginx-lb"
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = module.vpc.vpc_id
}
```
Se crean 2 security groups, uno que esta asignado a las instancias para que permitan el trafico del balanceador a la instancia al puerto 8080. Y el otro se le asigna al balanceador para que el puerto 8080 este a la escucha de las peticiones a travez de internet.
### Ansible
Como se ha mencionado anteriormente se tienen 2 playbooks uno el cual instala y configura nginx, y otro que configura e inicia el agente de cloud watch.
#### Nginx playbook
```file
---
- hosts: localhost
  tasks:
    - name: ensure nginx is at the latest version
      yum: name=nginx state=latest
      become: yes
    - name: copy the nginx config file
      copy:
        src: server.conf
        dest: /etc/nginx/conf.d/server.conf
      become: yes
    - name: copy the sample page
      copy:
        src: index.html
        dest: /usr/share/nginx/html/index.html
      become: yes
    - name: start nginx
      service:
          name: nginx
          state: started
      become: yes
```
#### CloudWatch playbook
```file
---
- hosts: localhost
  tasks:
    - name: copy the cloudwatch config file
      copy:
        src: cloudwatch-config.json
        dest: /opt/aws/amazon-cloudwatch-agent/bin/config.json
      become: yes
    - name: start cloudwatch agent
      shell:
        "/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json"
      register: cloudwatchcmd
    - debug: msg="{{cloudwatchcmd.stdout}}"
```
### Outputs
Al terminar la ejecucion de terraform arroja 2 valores como output, uno es el nombre del Auto Scaling Group y el otro es el endpoint para acceder a Nginx. Ejemplo:
```console
Apply complete! Resources: 21 added, 0 changed, 0 destroyed.

Outputs:

asg_name = "nginx"
lb_endpoint = "http://nginx-lb-2122329775.us-east-1.elb.amazonaws.com:8080"
```
Al entrar a la URL deberia de verse una pagina como esta:
![Page](https://i.imgur.com/6wsqZTt.png)

### Logging
Para encontrar los logs de las instancias debe iniciar sesion en AWS y dirigirse al servicio de CloudWatch > log groups, y buscar por el log group `nginx`, ahi encontrara los logs en tiempo real de nginx.
