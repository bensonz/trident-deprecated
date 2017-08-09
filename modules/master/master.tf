############################
# K8s Master Instances
############################
resource "aws_instance" "master" {
  count                       = "${var.master_count}"

  ami                         = "${var.master_ami}"
  instance_type               = "${var.master_instance_type}"

  root_block_device = {
    volume_type = "gp2"
    volume_size               = "${var.master_volume_size }"
  }

  vpc_security_group_ids      = ["${var.k8s_master_sg_id}"]
  subnet_id                   = "${var.k8s_subnet_id}"
  associate_public_ip_address = true
  iam_instance_profile        = "${var.k8s_iam_profile_name}"
  user_data                   = "${data.template_file.master_yaml.rendered}"
  key_name                    = "${var.ssh_key_name}"

  connection {
     type = "ssh",
     user                     = "${var.ssh_user_name}",
     private_key              = "${file(var.ssh_private_key_path)}"
  }

  # Generate k8s_master server certificate
  provisioner "local-exec" {
    command = <<EOF
${path.root}/cfssl/generate_server.sh apiserver "${self.public_ip},${self.private_ip},${var.k8s_service_ip},kubernetes.default,kubernetes"
EOF
  }
  # Provision apiserver server certificate
  provisioner "file" {
    source = "${path.root}/secrets/ca.pem"
    destination = "/home/core/ca.pem"
  }
  provisioner "file" {
    source = "${path.root}/secrets/apiserver.pem"
    destination = "/home/core/apiserver.pem"
  }
  provisioner "file" {
    source = "${path.root}/secrets/apiserver-key.pem"
    destination = "/home/core/apiserver-key.pem"
  }

  # Generate k8s_master client certificate
  provisioner "local-exec" {
    command = <<EOF
${path.root}/cfssl/generate_client.sh master
EOF
  }

  # Provision master client certificate
  provisioner "file" {
    source = "${path.root}/secrets/client-master.pem"
    destination = "/home/core/client.pem"
  }
  provisioner "file" {
    source = "${path.root}/secrets/client-master-key.pem"
    destination = "/home/core/client-key.pem"
  }
  # Move certificate into kubernetes/ssl
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/kubernetes/ssl",
      "sudo mv /home/core/{ca,apiserver,apiserver-key,client,client-key}.pem /etc/kubernetes/ssl/.",
    ]
  }

  tags {
    Name = "k8s-master-${count.index}"
  }
}

data "template_file" "master_yaml" {
  template = "${file("${path.module}/master.yaml")}"
  vars {
    CLUSTER_DOMAIN = "${var.cluster_domain}"
    DNS_SERVICE_IP = "${var.dns_service_ip}"
    ETCD_IP = "${var.etcd_private_ip}"
    POD_NETWORK = "${var.pod_network}"
    SERVICE_IP_RANGE = "${var.service_ip_range}"
    S3_LOCATION = "${var.s3_location}"
    FLANNEL_VERSION = "${var.flannel_version}"
    POD_INFRA_CONTAINER_IMAGE = "${var.pod_infra_container_image}"
    HYPERKUBE_ECR_LOCATION= "${var.ecr_location}"
    HYPERKUBE_IMAGE = "${var.kube_image}"
    HYPERKUBE_VERSION = "${var.kube_version}"
  }
}
