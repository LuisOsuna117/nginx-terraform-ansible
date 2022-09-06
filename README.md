# Nginx-Terraform-Ansible
![license](https://img.shields.io/github/license/LuisOsuna117/nginx-terraform-ansible)

Implementacion de un servidor web Nginx con Auto Scaling en AWS mediante Terraform y Ansible

- [Requisitos](#requisitos)
- [Diagrama](#diagrama)
- [Uso](#uso)
  - [Configuracion con aws-cli](#configuracion-con-aws-cli)
  - [Configuracion con variables de entorno](#configuracion-con-variables-de-entorno)

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


