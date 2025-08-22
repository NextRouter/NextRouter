#!/bin/bash

set -e

# Get the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utility, network, and monitoring scripts
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/network.sh"

# Function to display help message
show_help() {
    cat <<EOF
Usage: $0 [options]

Options:
  -w0, --wan0=<NIC>      Specify the WAN0 network interface.
  -w1, --wan1=<NIC>      Specify the WAN1 network interface.
  -l0, --lan0=<NIC>      Specify the LAN network interface.
  -lip, --local-ip=<IP>  Specify the LAN IP address with subnet (e.g., 192.168.1.1/24).
  -h, --help             Show this help message.
EOF
}

# Main function
main() {
    # Check for root privileges
    check_root

    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --wan0=*|-w0=*) WAN0="${1#*=}" ;;
            --wan1=*|-w1=*) WAN1="${1#*=}" ;;
            --lan0=*|-l0=*) LAN0="${1#*=}" ;;
            --local-ip=*|-lip=*) LAN_IP="${1#*=}" ;;
            -h|--help) show_help; exit 0 ;;
            *) error "Unknown option: $1"; show_help; exit 1 ;;
        esac
        shift
    done

    # Validate required arguments
    if [ -z "$WAN0" ] || [ -z "$WAN1" ] || [ -z "$LAN0" ] || [ -z "$LAN_IP" ]; then
        error "Missing one or more required arguments."
        show_help
        exit 1
    fi
    
    # Export variables to be available in sourced scripts
    export WAN0 WAN1 LAN0 LAN_IP

    # --- Network Setup ---
    log "Starting network setup..."
    install_network_packages
    setup_network_variables
    configure_dhcp
    setup_routing
    apply_nftables_rules
    create_routing_service
    finalize_network_setup
    success "Network setup finished."
    
    echo "Installing localPacletDump..."
    curl -sSL https://raw.githubusercontent.com/NextRouter/localPacletDump/main/install.sh| bash
    echo "localPacletDump installation complete."

    echo "Installing localPacletDump..."
    curl -sSL https://raw.githubusercontent.com/NextRouter/adaptiveRouting/main/install.sh | bash
    echo "localPacletDump installation complete."
    
    echo "Configuring Prometheus..."
    if [ -f "$SCRIPT_DIR/prometheus.yml" ]; then
        cp "$SCRIPT_DIR/prometheus.yml" /etc/prometheus/prometheus.yml
        systemctl restart prometheus
        success "Prometheus configuration applied."
    else
        warning "prometheus.yml not found in $SCRIPT_DIR"
    fi

    success "All setup tasks completed successfully!"
    info "Prometheus is accessible at http://${LAN_IP}:9090"
}

# Run main function with error handling
trap 'error "An error occurred. Aborting script."' ERR
main "$@"
