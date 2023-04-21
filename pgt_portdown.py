# This file contains the code to configure the Packet Generation Tool to generate packets when a port goes down

from ptf.testutils import *
app_id=3
p_count=1
pktlen=81
pktgen_port=68
port=46 # the port in which the port-down is activated, it should be a port from 17 (44) onwards

pktgen.enable( pktgen_port )
pda0 = pktgen.AppCfg_t( trigger_type=pktgen.TriggerType_t.PORT_DOWN,batch_count=0,pkt_count=p_count-1,ibg=1,ipg=1000,ipg_jitter=500,src_port=pktgen_port,src_port_inc=0,buffer_offset=0,length=pktlen-6 )
pktgen.cfg_app( app_id, pda0 )
MAC_PD = 'dd:aa:bb:ee:ff:aa' # the MAC address of the port-down packet that is generated
p = simple_eth_packet( pktlen=pktlen, eth_dst=MAC_PD, eth_type=0x1113 )
pktgen.write_pkt_buffer( 0, pktlen, bytes(p) )
pktgen.app_enable( app_id )
pktgen.clear_port_down( port ) # run this every time the port goes up again

#pktgen.app_disable( app_id )
#pktgen.disable( pktgen_port )