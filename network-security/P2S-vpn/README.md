# VPN
- The aim of using a VPN is to allow secure communication between devices and internal applications running in an Azure VNet over the internet — without using public IPs of VNet resources.
Traffic flowing over the internet is exposed to all kinds of threats. A VPN creates a secure tunnel through the internet.
- The VPN tunnel can use different protocols such as OpenVPN, Secure Socket Tunneling, and IKEv2, etc.
- Client computers need to authenticate to the VPN to access resources.
- This authentication can be done using a certificate, Entra ID, etc.

## There are two types of VPN connections:

- Point-to-Site (P2S) — VPN connection is established between an individual device (or devices) and a network. Example: When a remote employee logs in to their organization’s network from home.

- Site-to-Site (S2S) — VPN connection between two networks. This is an always-on connection. All devices on one network can automatically access the other network without requiring client software on individual devices. Example: Connection between the networks of an on-premises data center and the cloud or a hybrid cloud setup.

## Point-to-Site VPN: Implementation Overview
1. Deploy a Windows web server with Internet Information Services (IIS) - Test the connection with this server over the internet first, then remove its public IP. The goal is to connect to this server over the internet using a VPN.

2. Deploy a VPN Gateway - The VPN Gateway and its resources are deployed in a dedicated subnet called Gateway Subnet. The VPN Gateway will have a public IP.
(Cost consideration: VPN Gateways are billed per hour and can be expensive)

3. Authenticate clients - For lab purposes, we’ll use a self-signed certificate generated using a PowerShell script.

4. Download and install the VPN client from the VPN Gateway on the client machine to establish the VPN connection.


# P2S: Detailed Implementation


## 1. Setting up the Web Server

- Create a **resource group** named `app-grp`.
- Create a **VM** named `webvm01` in this resource group.  
  This VM will act as the **web server**.

### Configuration

- **Infrastructure redundancy:** Not required  
- **Region:** North Europe  
- **Image:** Windows Server 2022 Datacenter x64 Gen2  
- **Size:** Standard_D2s_v3 (2 vCPUs, 8 GB memory)  
- **Username:** `appadmin`  
- **Password:** `abcd1234`  
- **RDP inbound port:** 3389 (keep open)  

### Networking

- **Virtual Network (VNet):** `app-network`  
  - Address range: `10.0.0.0/16`
- **Subnet:** `websubnet`  
  - Address range: `10.0.0.0/24`
- **Public IP name:** `webvm01-ip`

### Steps

1. Once the VM is created, **download the RDP file** and connect to the VM.
2. Install **Internet Information Services (IIS)** on the VM (Web Server role).
3. On the server, create a `Default.html` page to check connectivity.  
   - Save the file in:  
     `C:\inetpub\wwwroot` (path from where IIS serves files).
4. On the server, open **Edge** and go to:  
   `localhost/Default.html`  
   → The webpage should load successfully (also verify from your local machine).
5. **Disassociate the public IP** from this server’s network interface.  
   - *(Consider automating this step using Terraform.)*

---

## 2. Setting up the VPN Gateway

- In the existing VNet (`app-network`), create a **Gateway Subnet**.

### Gateway Subnet Details

- **Purpose:** To host the Virtual Network Gateway
- **IPv4 range:** `10.0.0.0/16`

### Virtual Network Gateway Configuration

- **Instance name:** `app-gateway`
- **Region:** North Europe
- **Gateway type:** VPN
- **SKU:** VpnGw2
- **Generation:** Generation2
- **Virtual network:** `app-network`
- **Public IP name:** `gateway-ip`
- **Active-active mode:** Disabled
- **BGP:** Disabled

---

## 3. Creating a Certificate and Downloading the VPN Client

In **production environments**, a **trusted Certificate Authority (CA)** or an internal **certificate manager** is used.  
For this lab, we’ll create a **self-signed root certificate** and a **client certificate** using **PowerShell**.

### Steps

1. Create the **self-signed root certificate** and **client certificate** using **PowerShell** (run locally).
2. Verify that both the **client** and **root certificates** are created in **Manage User Certificates**.
   - Your system now has the **client certificate** and can authenticate to the VPN.
   - Any other machine needing VPN access will also need this **client certificate**.
3. Export the **public key** of the **root certificate** from your local machine and paste its content in the **Azure Portal**:
   - **VPN Gateway → Point-to-Site Configuration → Upload public key**
   - This allows the **VPN Gateway** to trust the certificates.
4. Once the public key upload is complete, **download the VPN client** from the Gateway and install it.
5. In your system’s **VPN settings**, you’ll now see `app-network` as an available connection.  
   Connect to it.
6. Open a web browser and type the **private IP** of the web server followed by `/Default.html`.

➡️ **You are now connected to the web server via VPN!**

