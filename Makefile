SHELL := /usr/bin/env bash

TOPOLOGY ?= srv6.yml
SRV6_TOPOLOGY ?= srv6-reference.yml
VPN_TOPOLOGY ?= srv6-vpn.yml
VPP_TOPOLOGY ?= srv6-vpp.yml

.PHONY: help deploy redeploy status interfaces graph gotty srv6 vpn reload verify verify-srv6 verify-vpn clean vpp vpp-status vpp-clean

help:
	@printf "SRv6 lab commands\n\n"
	@printf "  make deploy       Deploy main FRR topology (%s)\n" "$(TOPOLOGY)"
	@printf "  make redeploy     Recreate main FRR topology from base configs\n"
	@printf "  make status       Show nodes\n"
	@printf "  make interfaces   Show node interfaces\n"
	@printf "  make graph        Serve topology graph on http://0.0.0.0:50080\n"
	@printf "  make gotty        Attach web terminals\n"
	@printf "  make srv6         Deploy SRv6 reference topology for labs 5-7 and 10\n"
	@printf "  make vpn          Deploy SRv6 BGP L3VPN topology for lab 11\n"
	@printf "  make verify       Run basic health checks\n"
	@printf "  make verify-srv6  Run SRv6 locator/SID health checks\n"
	@printf "  make verify-vpn   Run BGP VPN/VRF health checks\n"
	@printf "  make clean        Destroy main topology\n"
	@printf "  make vpp          Deploy VPP topology for lab 8\n"
	@printf "  make vpp-clean    Destroy VPP topology\n"

deploy:
	containerlab deploy -t $(TOPOLOGY)

redeploy:
	containerlab deploy -t $(TOPOLOGY) --reconfigure

status:
	containerlab inspect -t $(TOPOLOGY)

interfaces:
	containerlab inspect interfaces -t $(TOPOLOGY)

graph:
	containerlab graph -t $(TOPOLOGY) --srv 0.0.0.0:50080

gotty:
	containerlab tools gotty attach -t $(TOPOLOGY)

srv6:
	containerlab deploy -t $(SRV6_TOPOLOGY) --reconfigure
	@sleep 20
	$(MAKE) verify-srv6

vpn:
	containerlab deploy -t $(VPN_TOPOLOGY) --reconfigure
	@sleep 5
	containerlab exec -t $(VPN_TOPOLOGY) --cmd "vtysh -b"
	@sleep 25
	$(MAKE) verify-vpn

reload:
	containerlab exec -t $(TOPOLOGY) --cmd "vtysh -b"

verify:
	containerlab exec -t $(TOPOLOGY) --cmd "hostname; ip -6 -br addr; vtysh -c 'show isis neighbor'"

verify-srv6:
	containerlab exec -t $(SRV6_TOPOLOGY) --cmd "hostname; vtysh -c 'show isis neighbor'; vtysh -c 'show segment-routing srv6 locator'; vtysh -c 'show segment-routing srv6 sid'; ip -6 route show table local | grep -i seg6local"

verify-vpn:
	docker exec clab-srv6-r1 ip link show TENANT_A
	docker exec clab-srv6-r1 ip -br link show tenant-a
	docker exec clab-srv6-r3 ip link show TENANT_A
	docker exec clab-srv6-r3 ip -br link show tenant-a
	containerlab exec -t $(VPN_TOPOLOGY) --cmd "hostname; vtysh -c 'show isis neighbor'; vtysh -c 'show bgp summary'"
	docker exec clab-srv6-r1 vtysh -c "show bgp ipv6 vpn"
	docker exec clab-srv6-r3 vtysh -c "show bgp ipv6 vpn"
	docker exec clab-srv6-r1 vtysh -c "show ipv6 route vrf TENANT_A"
	docker exec clab-srv6-r3 vtysh -c "show ipv6 route vrf TENANT_A"
	docker exec clab-srv6-r1 sh -c "ip -6 route show table local | grep -i 'End.DT\\|seg6local'"
	docker exec clab-srv6-r3 sh -c "ip -6 route show table local | grep -i 'End.DT\\|seg6local'"

clean:
	containerlab destroy -t $(TOPOLOGY)

vpp:
	containerlab deploy -t $(VPP_TOPOLOGY)

vpp-status:
	containerlab inspect -t $(VPP_TOPOLOGY)

vpp-clean:
	containerlab destroy -t $(VPP_TOPOLOGY)
