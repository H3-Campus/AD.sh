#!/bin/bash

# Function to process the output and create a formatted table
process_replication_info() {
    # Print header
    printf "%-20s | %-30s | %-10s | %-50s\n" "Server" "Last Sync" "Errors" "Domain"
    printf "%s\n" "$(printf '=%.0s' {1..115})"

    # Read input line by line
    while IFS= read -r line; do
        # Get domain name
        if [[ $line =~ ^[A-Z][A-Za-z=]+ ]]; then
            current_domain=${line}
            continue
        fi

        # Get server name
        if [[ $line =~ ^[[:space:]]+Default-First-Site-Name\\([^[:space:]]+) ]]; then
            server_name=${BASH_REMATCH[1]}
            continue
        fi

        # Get last sync time
        if [[ $line =~ Last[[:space:]]success[[:space:]]@[[:space:]](.+)$ ]]; then
            last_sync=${BASH_REMATCH[1]}
            if [[ $last_sync == "NTTIME(0)" ]]; then
                last_sync="Never"
            fi
        fi

        # Get error count
        if [[ $line =~ ([0-9]+)[[:space:]]consecutive[[:space:]]failure ]]; then
            errors=${BASH_REMATCH[1]}
            # Print the complete row
            printf "%-20s | %-30s | %-10s | %-50s\n" "$server_name" "$last_sync" "$errors" "$current_domain"
        fi
    done
}

# Main execution
echo "Samba Replication Status Report"
