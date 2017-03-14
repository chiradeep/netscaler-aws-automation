from fabric.api import run, parallel


@parallel
def start_traffic_gen(num_clients, num_requests, url):
    cmd = "ab -r -c {0} -n {1} {2}".format(num_clients, num_requests, url)
    run(cmd)
