# Tofino Failure Reaction Time (FRT)
This repo cotains the P4 code to measure the Failure Reaction Time (FRT) of a Tofino switch.


## Getting started
The Failure Raction Time (FRT) is defined as the time since the failure occurs until it is notified to the entities in charge of triggering the recovery process. Tofino switches internally maintain the state of their ports so when a port goes down the signal is used to trigger the packet generator, which generate packets that enter the pipeline of the specific switch in which the port goes down. In this way, the link down event is detected very quickly and the reaction can be triggered directly from the data plane with at almost zero delay. The target of this code is to measure the FRT, which is, how fast can the Tofino siwtch react to the link down event.

## Repo organization
- It contains a file called `forward_l2_interarrivaltime.p4`, which contains the data plane code.
- In addition to this, the corresponding control plane configuration is required to activate the packet generation tool that sends a packet when a port down event occurs.