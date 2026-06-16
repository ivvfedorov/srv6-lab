SHELL := /usr/bin/env bash

TOPOLOGY ?= srv6.yml
VPP_TOPOLOGY ?= srv6-vpp.yml

.PHONY: help deploy redeploy status interfaces graph gotty srv6 vpn reload verify clean vpp vpp-status vpp-clean

help:
	@printf "SRv6 lab commands\n\n"
	@printf "  make deploy       Deploy main FRR topology (%s)\n" "$(TOPOLOGY)"
	@printf "  make status       Show nodes\n"
	@printf "  make interfaces   Show node interfaces\n"
	@printf "  make graph        Serve topology graph on http://0.0.0.0:50080\n"
	@printf "  make gotty        Attach web terminals\n"
	@printf "  make srv6         Apply SRv6 reference configs for labs 5-7 and 10\n"
	@printf "  make vpn          Apply SRv6 BGP L3VPN configs for lab 11\n"
	@printf "  make verify       Run basic health checks\n"
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
	chmod +x labs/lab05-srv6-basic/apply-srv6.sh
	./labs/lab05-srv6-basic/apply-srv6.sh

vpn:
	chmod +x labs/lab11-srv6-vpn/apply-srv6-vpn.sh
	./labs/lab11-srv6-vpn/apply-srv6-vpn.sh

reload:
	containerlab exec -t $(TOPOLOGY) --cmd "vtysh -b"

verify:
	containerlab exec -t $(TOPOLOGY) --cmd "hostname; ip -6 -br addr; vtysh -c 'show isis neighbor'"

clean:
	containerlab destroy -t $(TOPOLOGY)

vpp:
	containerlab deploy -t $(VPP_TOPOLOGY)

vpp-status:
	containerlab inspect -t $(VPP_TOPOLOGY)

vpp-clean:
	containerlab destroy -t $(VPP_TOPOLOGY)
