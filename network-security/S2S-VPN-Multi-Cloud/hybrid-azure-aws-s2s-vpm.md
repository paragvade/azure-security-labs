# Hybrid S2S VPN: Azure ↔ AWS
Multi-cloud S2S VPN connection between Azure VNet and AWS VPC.

## The Story of Connecting Two Cloud Networks

Imagine you have two office buildings in different cities — one managed by Azure, one by AWS. Each building has its own private internal network where employees work. Today, these buildings have no way to communicate privately. Anyone wanting to share information would have to go through the public internet, exposed and unsecured.

Your job is to build a secure, private tunnel between them.

---

### Building the Offices First

Before you can connect two buildings, the buildings need to exist.

On the **Azure side**, you create a Virtual Network — this is your private address space (10.1.0.0/16). Within this, you carve out a workload subnet (10.1.1.0/24) where your actual servers will live. But you also need to reserve a special area called the Gateway Subnet. Azure is particular about this — it needs dedicated space to deploy its VPN infrastructure. Think of it as setting aside a room specifically for the networking equipment that will handle the secure tunnel.

On the **AWS side**, you create a VPC with its own address space (10.2.0.0/16). You add a private subnet (10.2.1.0/24) for your EC2 instances. AWS doesn't require a dedicated gateway subnet — it handles this differently internally.

At this point, you have two completely isolated networks. A VM in Azure has no idea the AWS VPC exists, and vice versa.

---

### Installing the VPN Equipment

Each building needs equipment capable of establishing an encrypted tunnel over the internet.

In **Azure**, you deploy a VPN Gateway into that Gateway Subnet you reserved. This is a managed service — Azure spins up redundant VMs behind the scenes, assigns them public IP addresses, and handles all the IPsec complexity. This deployment takes 45-60 minutes because Azure is provisioning real infrastructure. Once complete, your VPN Gateway has a public IP address — this is the "phone number" that the outside world can use to reach your Azure network's secure entrance.

In **AWS**, you create a Virtual Private Gateway and attach it to your VPC. This serves the same purpose — it's AWS's managed VPN endpoint. It gets its own public IP addresses (actually two, for redundancy). Creation is faster here because of how AWS architectures this service.

Now both buildings have their secure entrance points installed. But they still don't know about each other.

---

### Exchanging Contact Information

Here's where it gets interesting. Each side needs to know where the other side is and what networks sit behind it.

On the **AWS side**, you create something called a Customer Gateway. Despite the name, this isn't a gateway you're creating — it's a configuration object that represents the Azure VPN Gateway from AWS's perspective. You're essentially telling AWS: "There's a device at this IP address (Azure's public IP) that I want to establish a tunnel with. It uses BGP ASN 65515." AWS now knows where to reach Azure.

On the **Azure side**, you create a Local Network Gateway. Same concept, opposite direction. You're telling Azure: "There's a remote network I want to connect to. The VPN endpoint is at this IP address (AWS's tunnel IP), and the network ranges behind it are 10.2.0.0/16." Now Azure knows where to reach AWS and what traffic should be sent through the tunnel.

This exchange of information is crucial. Without the Local Network Gateway, Azure would have no idea that packets destined for 10.2.0.0/16 should go through the VPN tunnel. Without the Customer Gateway, AWS wouldn't know where to establish the IPsec connection.

---

### Establishing the Tunnel

With both sides knowing about each other, you can now create the actual connection.

On **AWS**, you create a Site-to-Site VPN Connection. This object links your Virtual Private Gateway (your equipment) to the Customer Gateway (your description of Azure). You specify the pre-shared key — a password that both sides must know. You also tell it which networks exist on the Azure side (10.1.0.0/16) so AWS can set up proper routing. AWS generates tunnel configurations, including outside IP addresses that Azure will connect to.

On **Azure**, you create a Connection on your VPN Gateway. You link it to the Local Network Gateway (your description of AWS) and provide the same pre-shared key. The keys must match exactly — this is how both sides prove their identity to each other during the IKE negotiation.

When both connections are configured, the gateways begin talking. They perform an IKE handshake — first establishing a secure channel to exchange keys (Phase 1), then negotiating the actual IPsec tunnel parameters (Phase 2). If the pre-shared keys match and the network settings align, the tunnel comes up.

---

### Making Traffic Flow

The tunnel exists, but your VMs still need to know to use it.

**Routing** is the final piece. When your Azure VM wants to reach 10.2.1.10 (an AWS address), the VM sends the packet to its default gateway. Azure's routing examines the destination, finds that 10.2.0.0/16 should go through the VPN Gateway (this route was created automatically when you set up the Local Network Gateway), and forwards the packet there. The VPN Gateway encrypts the packet, wraps it in IPsec headers, and sends it across the public internet to AWS's tunnel IP.

On the AWS side, the Virtual Private Gateway receives this encrypted blob, decrypts it, and sees a packet destined for 10.2.1.10. The VPC's route table (configured with route propagation from the VGW) knows this belongs to the private subnet, and delivers it to the EC2 instance.

The response follows the reverse path. The EC2 instance replies to 10.1.1.4, AWS routes it through the VGW, it gets encrypted, travels back through the tunnel, Azure decrypts it, and delivers it to your VM.

All of this happens transparently. To the applications, it appears as if they're on the same private network.

---

### The Security Groups and NSGs

One thing that often trips people up — the tunnel being established doesn't mean traffic flows freely. Both clouds have firewalls.

In **Azure**, the Network Security Group attached to your workload subnet must explicitly allow inbound traffic from 10.2.0.0/16. Otherwise, even though packets arrive through the tunnel, they get dropped at the subnet boundary.

In **AWS**, the Security Group attached to your EC2 instance must allow traffic from 10.1.0.0/16. Same principle — the tunnel delivers the packet, but the instance-level firewall has final say.

This is defense in depth. The VPN handles encryption and authentication. The security groups handle access control.

---

### The Order of Operations

You might wonder why the guide has you start Azure first, then do AWS, then go back and forth.

The Azure VPN Gateway takes 45-60 minutes to provision. Starting it first and then building AWS infrastructure in parallel is simply efficient use of time.

But there's also a dependency chain. You can't create the AWS Customer Gateway until you know Azure's public IP — which only exists after the Azure VPN Gateway deploys. You can't create Azure's Local Network Gateway until you know AWS's tunnel IP — which only exists after you create the AWS VPN Connection.

The flow follows these dependencies while parallelizing where possible.

---

## Lab Results

### Connectivity Proof
**Azure VM → AWS EC2** <br>
> Azure VM (10.1.1.4) pinging AWS EC2 (10.2.1.109). 0% packet loss, ~5ms latency. S2S VPN tunnel operational.

<img width="568" height="211" alt="ping-azure-to-aws" src="https://github.com/user-attachments/assets/14daf328-cfdb-4231-8d0a-397225933283" />


**AWS EC2 → Azure VM**
> AWS EC2 (10.2.1.109) pinging Azure VM (10.1.1.4). 0% packet loss, ~5ms latency. Bidirectional connectivity confirmed.

<img width="596" height="250" alt="ping-aws-to-azure" src="https://github.com/user-attachments/assets/2d26227b-a13b-42d8-9447-6b1a978cab72" />

---

### Tunnel Status

**Azure Connection Status**
 

> Azure VPN connection showing "Connected" status with Local Network Gateway pointing to AWS Tunnel IP (54.157.190.87). Data flowing: 420 bytes in/out.

<img width="1914" height="465" alt="azure-aws-connection" src="https://github.com/user-attachments/assets/39434a69-fe9b-4f0d-a24a-94377dd95e50" />

**AWS Tunnel Status**

 
> AWS Site-to-Site VPN connection showing Tunnel 1 status "UP" with Customer Gateway pointing to Azure VPN Gateway IP (57.151.32.26).

<img width="1913" height="867" alt="aws-azure-connection" src="https://github.com/user-attachments/assets/d58ac62b-a59d-4707-b26b-c320ee1d463e" />

---

### Azure Resources

**Resource Group Overview**

> All Azure resources for S2S VPN lab: VPN Gateway, Local Network Gateway, VNet, NSG, VM, and supporting resources.

<img width="1330" height="766" alt="azure-rg" src="https://github.com/user-attachments/assets/06cd5145-e771-4ba9-9af6-73a8f0b41095" />


**VNet Subnets**

> Azure VNet with workload-subnet (10.1.1.0/24) for VMs and GatewaySubnet (10.1.255.0/27) for VPN Gateway.

<img width="1907" height="630" alt="azure subnets" src="https://github.com/user-attachments/assets/2aef419e-0707-4ff6-95a5-3ad9a8be0320" />

**VPN Gateway Connections**

> VPN Gateway connection to AWS showing "Connected" status via aws-local-gateway peer.

<img width="1914" height="694" alt="azure-vpn-gateway" src="https://github.com/user-attachments/assets/f3efa43c-10df-4e38-8ee1-18230f817dea" />


**Local Network Gateway**

> Local Network Gateway representing AWS. Connection type: Site-to-site (IPsec), Status: Connected.

<img width="1907" height="553" alt="azure-local-gateway" src="https://github.com/user-attachments/assets/034afed8-8b27-415a-ba82-1f048d00c98f" />
 

---

### AWS Resources

**VPC Resource Map**

> AWS VPC (10.2.0.0/16) architecture showing private-subnet (10.2.1.0/24), route tables, and internet gateway.

<img width="1631" height="395" alt="aws-vpc-resource-map" src="https://github.com/user-attachments/assets/4f5d56c1-1165-4024-b1db-445efa1b96c5" />
 
**Customer Gateway**

> Customer Gateway representing Azure VPN Gateway. BGP ASN 65515 (Azure default), IP address 57.151.32.26.
<img width="1911" height="549" alt="aws-customer-gateway" src="https://github.com/user-attachments/assets/ae4cf232-1032-4a76-b4a4-4f3ce27ee9d9" />




