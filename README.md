# Tofino Failure Reaction Time (FRT)
This repo cotains the P4 code to measure the Failure Reaction Time (FRT) of an Intel Tofino ASIC based switch.


## Getting started
#### FRT
The Failure Raction Time (FRT) is defined as the time since the failure occurs until it is notified to the entities in charge of triggering the recovery process. Tofino switches internally maintain the state of their ports so when a port goes down the signal is used to trigger the packet generator, which generate packets that enter the pipeline of the specific switch in which the port goes down. In this way, the link down event is detected very quickly and the reaction can be triggered directly from the data plane with at almost zero delay. The target of this code is to measure the FRT, which is, how fast can the Tofino siwtch react to the link down event.
#### Measurement methodology
Every time a data packet arrives at the ingress pipeline of the switch a timestamp `ts1` is stored in a register. Then, we disconnect the link between `h1` and the switch so a port-down packet is generated and sent to the data plane of the switch. When the port-down packet arrives at the ingress pipeline of the data plane, a new timestamp `ts2` is and previously stored `ts1` are attached to the packet. The resulting packet is finally forwarded to the port 1, so it reaches `h2` where it is processed to compute the FRT as the difference between `ts2` and `ts1`.

## Repo organization
- The file `forward_l2_pd.p4` contains the P4 data plane code to measure the FRT.
- The file `forward_l2_interarrivaltime.p4` contains the P4 data plane code to measure the packet interarrival time.
- In addition to this, the corresponding control plane configuration is required to activate the packet generation tool that sends a packet when a port down event occurs.
