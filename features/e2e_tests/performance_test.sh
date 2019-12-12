#!/bin/bash

function local_env() {
    BASEDIR="$(dirname "$0")"
    source "${BASEDIR}/../lib/functions.sh"
}

function validate_function_by_worker() {
    WORKERS=("$(oc get node -l node-role.kubernetes.io/worker -o jsonpath="{range .items[*]}{.metadata.name} ")")
    if [ -z "${WORKERS}" ];then
        die "===> No workers detected, exiting..."
    fi

    for worker in "${WORKERS[@]}"
    do
        CHECKS=( 
            # Kernel generic checks
            "KERNEL_PREEMPTION:$(oc debug node/${worker} -- chroot /host uname -v 2>/dev/null | grep -c PREEMPT)"
            "KERNEL_REAL_TIME:$(oc debug node/${worker} -- chroot /host uname -v 2>/dev/null | grep -c RT)"
            "KERNEL_VERSION:$(oc debug node/${worker} -- chroot /host uname -r 2>/dev/null | grep -c rt)"
            # Checks here https://github.com/openshift-kni/baremetal-deploy/blob/master/features/performance/manifests/templates/00-tuned-network-latency.yaml.in 
            "PERF_SYSCTL_CORE_BUSY_READ:$(oc debug node/${worker} -- chroot /host sysctl -n net.core.busy_read 2>/dev/null | grep -c 50)"
            "PERF_SYSCTL_CORE_BUSY_POLL:$(oc debug node/${worker} -- chroot /host sysctl -n net.core.busy_poll 2>/dev/null | grep -c 50)"
            "PERF_SYSCTL_CORE_TCP_FASTOPEN:$(oc debug node/${worker} -- chroot /host sysctl -n net.ipv4.tcp_fastopen 2>/dev/null | grep -c 3)"
            "PERF_SYSCTL_KERN_NUMA_BALANC:$(oc debug node/${worker} -- chroot /host sysctl -n kernel.numa_balancing 2>/dev/null | grep -c 0)"
            "PERF_SYSCTL_KERN_SCHED_GRANDULARITY:$(oc debug node/${worker} -- chroot /host sysctl -n kernel.sched_min_granularity_ns 2>/dev/null | grep -c 10000000)"
            "PERF_SYSCTL_VM_DIRTY_RATIO:$(oc debug node/${worker} -- chroot /host sysctl -n vm.dirty_ratio 2>/dev/null | grep -c 10)"
            "PERF_SYSCTL_VM_DIRTY_BACKGROUND_RATIO:$(oc debug node/${worker} -- chroot /host sysctl -n vm.dirty_background_ratio 2>/dev/null | grep -c 3)"
            "PERF_SYSCTL_VM_SWAPPINESS:$(oc debug node/${worker} -- chroot /host sysctl -n vm.swappiness 2>/dev/null | grep -c 10)"
            "PERF_SYSCTL_KERN_SCHED_MIGRA_COST:$(oc debug node/${worker} -- chroot /host sysctl -n kernel.sched_migration_cost_ns 2>/dev/null | grep -c 5000000)"
            # Checks for RT-Kernel Params here: https://github.com/openshift-kni/baremetal-deploy/blob/master/features/performance/manifests/templates/11-machine-config-worker-rt-kernel.yaml.in
            "PERF_RT_KERN_PATCH:$(oc debug node/${worker} -- chroot /host ls -d /usr/local/bin/rt-kernel-patch.sh 2>/dev/null | wc -l)"
            "PERF_KUBE_CONFIG_WORKER_RT:$(oc debug node/${worker} -- chroot /host grep -c 'hugepagesz=1G' /proc/cmdline 2>/dev/null)"
            "PERF_KERN_ARGS_HUGE_PAGES:$(oc debug node/${worker} -- chroot /host grep -c 'hugepages=32' /proc/cmdline 2>/dev/null)"
            "PERF_KERN_ARGS_DEF_HUGE_PAGES:$(oc debug node/${worker} -- chroot /host grep -c 'default_hugepagesz=1G' /proc/cmdline 2>/dev/null)"
            # Checks for Tunning Operator here: https://github.com/openshift-kni/baremetal-deploy/blob/master/features/performance/manifests/templates/12-tuned-worker-rt.yaml.in
            "PERF_SYSCTL_KERN_HUNG_TASK_TIMEOUT:$(oc debug node/${worker} -- chroot /host sysctl -n kernel.hung_task_timeout_secs 2>/dev/null | grep -c 600)"
            "PERF_SYSCTL_KERN_NMI_WATCHDOG:$(oc debug node/${worker} -- chroot /host sysctl -n kernel.nmi_watchdog 2>/dev/null | grep -c 0)"
            "PERF_SYSCTL_KERN_SCHED_RT_RUNTIME:$(oc debug node/${worker} -- chroot /host sysctl -n kernel.sched_rt_runtime_us 2>/dev/null | grep -c '\-1')"
            "PERF_SYSCTL_VM_STAT_INTERVAL:$(oc debug node/${worker} -- chroot /host sysctl -n vm.stat_interval 2>/dev/null | grep -c 10)"
            "PERF_SYSCTL_KERN_TIMER_MIGRATION:$(oc debug node/${worker} -- chroot /host sysctl -n kernel.timer_migration 2>/dev/null | grep -c 0)"
        )

        validate_function
    done
}

CHECKS=( 
    "PERF_MC_RT_KERN:$(oc get mc --no-headers 11-worker-rt-kernel 2>/dev/null | wc -l)"
    "PERF_FEAT_GATE:$(oc get FeatureGate -o jsonpath='{.spec.featureSet}' 2>/dev/null | grep -c LatencySensitive)"
    "PERF_KUBE_CONFIG_WORKER_RT:$(oc get KubeletConfig -o jsonpath='{.spec.kubeletConfig.topologyManagerPolicy}' 2>/dev/null | grep -c best-effort)"
)

declare -a test_results test_ok test_nok test_failed
local_env
validate_function
validate_function_by_worker
resume "Performance Tuning"
