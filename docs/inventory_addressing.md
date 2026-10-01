# Inventory IP Addressing Scheme

## Overview

RHIS assigns fixed IP addresses to infrastructure nodes from a structured band
allocation scheme within the deployment network. Every node type is assigned a
contiguous band of addresses with defined boundaries and a documented maximum
count. This ensures that IP allocations never collide, regardless of how many
node types are deployed simultaneously.

The addressing scheme is enforced at render time by `inventory_update.yml`,
which validates all system counts against the limits defined in
`inventory_basevars_limits.yml` before rendering the deployment inventory.

## Design Principles

**Band isolation.** Each service group occupies its own address band. Bands are
sized to accommodate the maximum expected node count for that service, with no
overlap between adjacent bands. This eliminates the IP collision problem that
existed in the original offset-arithmetic scheme, where scaling one group would
silently overwrite addresses allocated to another.

**Emergency address reservation.** The first address in each band (the address
ending in 0) is reserved and not assigned to any node. This address is available
for emergency operations such as re-IPing a failed node, temporary maintenance
interfaces, or disaster recovery scenarios where a replacement node must be
brought online before the original is fully decommissioned.

**Consistent formula.** Every dynamically allocated node uses the same offset
formula: `next_nth_usable(BAND_BASE + num)` where `num` counts from 1. This
replaces the previous mix of hardcoded offsets and arithmetic expressions that
were difficult to reason about at scale.

**Infrastructure reserved range.** Addresses .1 through .9 are reserved for
network infrastructure that exists outside of RHIS management: gateways,
time servers, storage arrays, and other pre-existing equipment.

## Band Allocation Table

The following table defines the current allocation. The band map is also
documented as a header comment in `inventory_template/inventory/inventory.j2`.

| Band | Offsets | Purpose | .x0 Reserved | Host Offsets | Max Nodes |
|------|---------|---------|--------------|--------------|-----------|
| — | 1-9 | Infrastructure (gateways, NTP, NAS) | — | — | — |
| 10 | 10-29 | IdM | 10 = primary | 11-26 | 16 replicas |
| 30 | 30-39 | Core services | 30 = emergency | 31=gitea, 32=satellite, 33=provisioner, 34=logserver | fixed |
| 40 | 40-49 | Satellite capsules | 40 = emergency | 41-46 | 6 |
| 50 | 50-59 | AAP gateways | 50 = emergency | 51-59 | 9 |
| 60 | 60-69 | AAP controllers | 60 = emergency | 61-69 | 9 |
| 70 | 70-79 | AAP EDA controllers | 70 = emergency | 71-79 | 9 |
| 80 | 80-94 | VMware (vCenter + ESXi) | 80 = vCenter | 81-94 | 14 ESXi |
| — | 95-99 | Buffer | — | — | — |
| 100 | 100-109 | AAP hubs | 100 = emergency | 101-109 | 9 |
| 110 | 110-119 | AAP databases | 110 = emergency | 111-119 | 9 |
| 120 | 120-129 | AAP execution nodes | 120 = emergency | 121-129 | 9 |
| 130 | 130-139 | AAP hop nodes | 130 = emergency | 131-139 | 9 |
| 140 | 140-149 | KVM hypervisors | 140 = emergency | 141-149 | 9 |
| 150 | 150-159 | Quay | 150 = emergency | 151-159 | 9 |
| 160 | 160-179 | Quadlet | 160 = emergency | 161-178 | 18 |
| 180+ | — | Future expansion | — | — | — |

On a /22 network (1022 usable addresses), this scheme uses addresses up to
offset 179 at maximum capacity, leaving substantial room for future growth.

## System Count Limits

`inventory_basevars_limits.yml` defines the maximum allowed count for each node
type. This file is set to read-only (mode 0444) so that only root can modify
permissions before editing. This is intentional — changing a limit has
implications for the IP band allocation and must be done with care.

`inventory_update.yml` validates every entry in `rhis_system_count` against
these limits before rendering. If a limit is exceeded, the render fails with a
message directing the user to reduce the count or consult this documentation.

## Increasing a Limit

Increasing the maximum count for an existing node type requires careful
consideration of the band boundaries. Before changing a limit:

1. **Check for band overflow.** Determine whether the current band has room for
   the increased count. For a standard decade band (e.g., offsets 50-59), the
   maximum is 9 hosts (offsets 51-59, with 50 reserved). Exceeding this
   requires widening the band.

2. **Check adjacent bands.** If the band must be widened, verify that the
   expanded range does not overlap with the next band. For example, increasing
   AAP gateways beyond 9 would push into the AAP controllers band at offset 60.

3. **Adjust the band allocation.** If overlap would occur, shift all subsequent
   bands to create room. This means updating:
   - The offset formulas in `inventory_template/inventory/inventory.j2`
   - The band map comment at the top of that file
   - The limit in `inventory_basevars_limits.yml`

4. **Re-render all deployments.** After changing band boundaries, every
   deployment that uses the affected bands must be re-rendered with
   `inventory_update.sh`. Nodes that received new IP addresses will need
   to be reprovisioned or re-IPed.

5. **Update the limits file.** After adjusting the template, update the limit
   in `inventory_basevars_limits.yml`. Root must first change the file
   permissions:
   ```
   sudo chmod 644 inventory_basevars_limits.yml
   # edit the file
   sudo chmod 444 inventory_basevars_limits.yml
   ```

## Adding a New Server Type

Adding an entirely new type of server to the inventory requires allocating a
new IP band. Before proceeding:

1. **Choose a band.** Select an unused offset range from the available space
   (offset 180 and above is currently unallocated). Follow the convention of
   decade-wide bands for groups of up to 9 nodes, or wider bands for larger
   groups (e.g., quadlet uses a 20-wide band for 18 nodes).

2. **Reserve the emergency address.** The first address in the band (the .x0
   address) must be reserved and not assigned to any host.

3. **Add the template block.** Add a conditional section to
   `inventory_template/inventory/inventory.j2` following the existing pattern:
   ```jinja2
   {% if rhis_system_count.new_type is defined and rhis_system_count.new_type > 0 %}
   new_type_group:
     hosts:
   {% for num in range(1, (rhis_system_count.new_type | int) + 1) %}
       {{ 'newtype' ~ num ~ '.' ~ basevars_global_domain_name }}:
         ipv4_address: "{{ [default_network, '/', default_network_prefix] | join() | ansible.utils.next_nth_usable(BAND_BASE + num) }}"
   {% endfor %}
   {% endif %}
   ```

4. **Add the limit.** Add an entry to `inventory_basevars_limits.yml` for the
   new type with the appropriate maximum count. Root permissions are required.

5. **Add the basevars key.** Add the new key to `rhis_system_count` in:
   - `inventory_basevars.yml` (the sample/template)
   - Each deployment-specific basevars file (gitignored, per-environment)

6. **Update the band map.** Update both the comment header in `inventory.j2`
   and this document with the new band allocation.

If a new server type appears in `rhis_system_count` without a matching entry in
`inventory_basevars_limits.yml`, `inventory_update.yml` will issue a warning
during rendering. The unrecognized type will not be rendered in the inventory
and no hosts will be created for it.

## Growth Mode vs Enterprise Mode

The AAP gateway group has special handling for single-node deployments. When
`aapgateway: 0` and `aapcontroller: 1`, the template creates the `aap_gateways`
group pointing to `aapcontroller1` — the single controller serves as the
gateway. This is the "growth mode" topology where all AAP services are
co-located on one host.

When `aapgateway` is greater than 0, dedicated gateway nodes are provisioned
in the gateway band (offsets 51-59) and the controller nodes are separate in
the controller band (offsets 61-69). This is the "enterprise mode" topology.

## Bare Metal Considerations

Satellites, capsules, and log servers are deployed on bare metal with local
NVMe storage. These hosts are not provisioned through VMware compute resources
and will not have `compute_resource` or `compute_profile` entries. They are
provisioned via kickstart/OEMDRV through `rhis-builder-bootstrap-init` (for
phase 1 hosts) or through Satellite with ansible callbacks (for phase 5 hosts).
