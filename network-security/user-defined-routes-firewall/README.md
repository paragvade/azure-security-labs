# User Defined Routes with Central Firewall VM

## Scenario

Large organizations often route all subnet traffic through a central firewall virtual machine that sits in a dedicated subnet.  
Azure System Routes normally allow traffic to flow directly between subnets in a virtual network, but **User** Defined Routes (UDRs) let us override this and force traffic to a specific next hop (the firewall VM NIC).

In this lab:

- Start with two workload VMs in different subnets that can communicate directly using system routes.
- Introduce a third VM acting as a central firewall in its own subnet.
- Create a route table and UDR so traffic between the workload subnets is forced through the firewall VM.
- Enable IP forwarding on the firewall VM so it can actually route the traffic.

## Architecture

- One VNet, e.g. `10.0.0.0/16`.
- Subnets:
  - `workload-subnet-a` (workload VM A).
  - `workload-subnet-b` (workload VM B).
  - `firewall-subnet` (central firewall VM).
  - Route table: rt-workloads-via-firewall associated with both workload subnets.
  - Route: `0.0.0.0/0` → Next hop: Virtual appliance → IP of firewall VM NIC.

## Lab steps (high level)

1. **Baseline connectivity with system routes**
   - Deploy the VNet with `workload-subnet-a` and `workload-subnet-b`.
   - Deploy one Linux VM in each subnet.
   - From VM A, test connectivity to VM B using `ping` and `curl` to confirm that traffic flows directly using Azure system routes.

2. **Introduce the central firewall VM**
   - Create `firewall-subnet`.
   - Deploy a third Linux VM (firewall VM) into `firewall-subnet`.
   - Note the private IP address of the firewall VM NIC.

3. **Create route table and UDR**
   - Create a route table.
   - Add a UDR with:
     - Address prefix: `0.0.0.0/0` (or a more specific prefix if you want to limit the scope).
     - Next hop type: `Virtual appliance`.
     - Next hop IP: firewall VM NIC private IP.
   - Associate the route table with both workload subnets.
   - At this point, system routes are overridden and traffic between workload subnets is *forced* to go via the firewall VM, but routing will not work yet.

4. **Enable IP forwarding on the firewall VM**
   - NIC layer: enable **IP forwarding** on the firewall VM network interface in the Azure portal.
   - OS layer:
     - SSH into the firewall VM.
     - Edit `/etc/sysctl.conf` and ensure `net.ipv4.ip_forward=1` is uncommented.
     - Apply the change with `sudo sysctl -p` and restart the VM if required.

5. **Re-test connectivity**
   - From VM A, again `ping` / `curl` VM B.
   - Confirm that:
     - Before IP forwarding was enabled, traffic failed because the firewall VM was not routing.
     - After IP forwarding is enabled, traffic succeeds, proving that the UDR is sending traffic via the firewall VM and that it is forwarding packets correctly.
   - In the Azure portal, use **Network interface → Effective routes** on the workload VMs to verify that the UDR is in effect and the next hop is the firewall VM.

## Files

- `README.md` – this lab guide, background, and verification steps.
- `iac/main.tf` – Terraform configuration for VNet, subnets, VMs, route table, and UDR.
- `iac/variables.tf` – Input variables (location, prefixes, admin username, etc.).
- `iac/outputs.tf` – Useful outputs like VM public IPs and firewall NIC IP.
