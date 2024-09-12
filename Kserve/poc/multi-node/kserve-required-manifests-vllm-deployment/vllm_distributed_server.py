import ray
import time

def monitor_cluster():
    ray.init(address='auto')
    previous_nodes = set()

    while True:
        current_nodes = set(ray.cluster_resources().keys())
        added_nodes = current_nodes - previous_nodes
        removed_nodes = previous_nodes - current_nodes

        if added_nodes:
            print(f"New nodes added: {added_nodes}")
        if removed_nodes:
            print(f"Nodes removed: {removed_nodes}")

        previous_nodes = current_nodes
        time.sleep(60) 

monitor_cluster()
