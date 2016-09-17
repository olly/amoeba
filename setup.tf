provider "aws" {
  region = "eu-west-1"
}

resource "aws_vpc" "amoeba" {
  cidr_block = "192.168.254.0/28"

  tags {
    Name = "amoeba"
  }
}

resource "aws_internet_gateway" "amoeba" {
  vpc_id = "${aws_vpc.amoeba.id}"

  tags {
    Name = "amoeba"
  }
}

resource "aws_route" "internet" {
    route_table_id = "${aws_vpc.amoeba.main_route_table_id}"
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.amoeba.id}"
}

resource "aws_subnet" "amoeba-eu-west-1a" {
  vpc_id = "${aws_vpc.amoeba.id}"
  availability_zone = "eu-west-1a"
  cidr_block = "192.168.254.0/28"

  tags {
    Name = "amoeba - eu-west-1a"
  }
}

resource "aws_security_group_rule" "amoeba-ssh" {
  type = "ingress"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_vpc.amoeba.default_security_group_id}"
}

resource "aws_key_pair" "amoeba" {
  key_name = "amoeba"
  public_key = "${file("tmp/amoeba-ssh.pub")}"
}

resource "aws_instance" "amoeba" {
  ami = "ami-7abd0209"
  instance_type = "t2.nano"
  key_name = "${aws_key_pair.amoeba.key_name}"
  subnet_id = "${aws_subnet.amoeba-eu-west-1a.id}"
  vpc_security_group_ids = ["${aws_vpc.amoeba.default_security_group_id}"]
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp2"
  }

  ebs_block_device {
    device_name = "/dev/sdb"
    volume_size = 8
    volume_type = "gp2"
  }

  tags {
    Name = "amoeba"
  }

  connection {
    host = "${aws_instance.amoeba.public_ip}"
    user = "centos"
    private_key = "${file("tmp/amoeba-ssh")}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /build",
      "sudo mkdir -p /build/mount",
      "sudo chown -R centos:centos /build"
    ]
  }

  provisioner "file" {
    source = "files"
    destination = "/build"
  }

  provisioner "file" {
    source = "scripts"
    destination = "/build"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /build/scripts/build.sh",
      "sudo /build/scripts/build.sh",
    ]
  }
}
