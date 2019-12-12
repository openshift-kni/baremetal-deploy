# E2E Tests

## Test execution

The way to execute the tests it's quite easy:

- Input:
```
bash performance_test.sh
```

or 

```
./performance_test.sh
```

- Output:
```
===> Performance Tuning results: (16/8/24) (OK/NOK/TESTS)
PERF_FEAT_GATE: Test Failed!
PERF_KUBE_CONFIG_WORKER_RT: Test Failed!
KERNEL_PREEMPTION: Test Failed!
KERNEL_REAL_TIME: Test Failed!
KERNEL_VERSION: Test Failed!
PERF_KUBE_CONFIG_WORKER_RT: Test Failed!
PERF_KERN_ARGS_HUGE_PAGES: Test Failed!
PERF_KERN_ARGS_DEF_HUGE_PAGES: Test Failed!
```

The result will be something like this `(16/8/24)` where the first field is the successful tests, the second one failed tests, and the third one how many tests has been executed.

## Adding more tests

- Create a new file with the sufix `_test.sh`
- Include the function `local_env` and call it on the body, to load the shared `functions.sh`
- If your tests need to access to a worker to be executed include the `validate_function_by_worker` where:
    - You iterates by all the workers you have on your deployment
    - Add the checks on the `CHECKS` map and using the prefix of `oc debug node/${worker} -- chroot /host ...`
    - This is how looks like a test: `"KERNEL_PREEMPTION:$(oc debug node/${worker} -- chroot /host uname -v 2>/dev/null | grep -c PREEMPT)"`
    - After fill the `CHECKS` map, you must call the `validate_function` into the loop, in order to execute the commands and validate the tests
    - Then in the body of the script, call this function
    - *HINT:* Try to copy/paste the structure of already existant test.
- If your tests includes just validations against the OCP API, you must just fill the `CHECKS` map and call `validate_function` in the script body
- In order to get the results call the function `resume` with the title you want to show up, like `resume "PTP"`
