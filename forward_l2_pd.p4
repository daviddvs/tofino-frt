/* -*- P4_16 -*- */

#include <core.p4>
#include <tna.p4>

/*************************************************************************
 ************* C O N S T A N T S    A N D   T Y P E S  *******************
**************************************************************************/
const bit<16> ETHERTYPE_TPID = 0x8100;
const bit<16> ETHERTYPE_IPV4 = 0x0800;
const bit<9>  PORT_DOWN = 68;
const bit<8>  POS_TS1 = 0;
const bit<8>  POS_TS2 = 1;

typedef bit<32> ts_t;

/* Table Sizes */
const int IPV4_HOST_SIZE = 65536;
const int IPV4_LPM_SIZE  = 12288;

/*************************************************************************
 ***********************  H E A D E R S  *********************************
 *************************************************************************/

/*  Define all the headers the program will recognize             */
/*  The actual sets of headers processed by each gress can differ */

/* Standard ethernet header */
header ethernet_h {
    bit<48>   dst_addr;
    bit<48>   src_addr;
    bit<16>   ether_type;
}

header vlan_tag_h {
    bit<3>   pcp;
    bit<1>   cfi;
    bit<12>  vid;
    bit<16>  ether_type;
}

/* Timestamping headers */
header timestamps_ingress_h {
    ts_t ts2;
    ts_t ts1;
}

/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
 
    /***********************  H E A D E R S  ************************/

struct my_ingress_headers_t {
    pktgen_port_down_header_t   portdown;
    ethernet_h                  ethernet;
    timestamps_ingress_h        ts_ingress;
}

    /******  G L O B A L   I N G R E S S   M E T A D A T A  *********/

struct my_ingress_metadata_t {
}

    /***********************  P A R S E R  **************************/
parser IngressParser(packet_in        pkt,
    /* User */    
    out my_ingress_headers_t          hdr,
    out my_ingress_metadata_t         meta,
    /* Intrinsic */
    out ingress_intrinsic_metadata_t  ig_intr_md)
{
    /* This is a mandatory state, required by Tofino Architecture */
     state start {
        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        transition select (ig_intr_md.ingress_port) {
            PORT_DOWN: parse_portdown;
            default: parse_ethernet;
        } 
    }

    state parse_portdown {
        pkt.extract(hdr.portdown);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition accept;
    }

}

    /***************** M A T C H - A C T I O N  *********************/

control Ingress(
    /* User */
    inout my_ingress_headers_t                       hdr,
    inout my_ingress_metadata_t                      meta,
    /* Intrinsic */
    in    ingress_intrinsic_metadata_t               ig_intr_md,
    in    ingress_intrinsic_metadata_from_parser_t   ig_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t        ig_tm_md)
{

    action send_l2(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
    }

    action drop_l2() {
        ig_dprsr_md.drop_ctl = 1;
    }

    

    table forward_l2 {
        key     = { hdr.ethernet.dst_addr : exact; }
        actions = { send_l2; drop_l2; }
        default_action = drop_l2();
        size           = IPV4_LPM_SIZE;
    }

    
    Register<bit<32>,bit<8>>(128) ts;
    
    RegisterAction<bit<32>,bit<8>,bit<32>> (ts)
    write_ts = {
        void apply(inout bit<32> register_data) {
            register_data = ig_prsr_md.global_tstamp[31:0];
        }
    };

    RegisterAction<bit<32>,bit<8>,bit<32>> (ts)
    read_ts = {
        void apply(inout bit<32> register_data, out bit<32> result) {
            result = register_data;
            register_data = 0x010101010101; //Overwrite with junk
        }
    };
    

    //Register<bit<32>,bit<8>>(128) ts;
    apply {
        if (hdr.ethernet.isValid()) {
            if(hdr.portdown.isValid()) {
                hdr.ts_ingress.setValid();
                //hdr.ts_ingress.ts1 = ig_intr_md.ingress_mac_tstamp; 
                hdr.ts_ingress.ts2 = ig_prsr_md.global_tstamp[31:0];
                hdr.ts_ingress.ts1 = read_ts.execute(POS_TS1);
                //hdr.ts_ingress.ts1 = (ts_t) ts.read(POS_TS1);
            }
            else {
                write_ts.execute(POS_TS1);
                //ts.write((bit<8>)POS_TS1, (bit<32>)ig_prsr_md.global_tstamp);
            }
            forward_l2.apply();
        }
    }    

}

    /*********************  D E P A R S E R  ************************/

control IngressDeparser(packet_out pkt,
    /* User */
    inout my_ingress_headers_t                       hdr,
    in    my_ingress_metadata_t                      meta,
    /* Intrinsic */
    in    ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md)
{
    apply {
        pkt.emit(hdr.ethernet);
        pkt.emit(hdr.portdown);
        pkt.emit(hdr.ts_ingress);
    }
}


/*************************************************************************
 ****************  E G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/

    /***********************  H E A D E R S  ************************/

struct my_egress_headers_t {
}

    /********  G L O B A L   E G R E S S   M E T A D A T A  *********/

struct my_egress_metadata_t {
}

    /***********************  P A R S E R  **************************/

parser EgressParser(packet_in        pkt,
    /* User */
    out my_egress_headers_t          hdr,
    out my_egress_metadata_t         meta,
    /* Intrinsic */
    out egress_intrinsic_metadata_t  eg_intr_md)
{
    /* This is a mandatory state, required by Tofino Architecture */
    state start {
        pkt.extract(eg_intr_md);
        transition accept;
    }
}

    /***************** M A T C H - A C T I O N  *********************/

control Egress(
    /* User */
    inout my_egress_headers_t                          hdr,
    inout my_egress_metadata_t                         meta,
    /* Intrinsic */    
    in    egress_intrinsic_metadata_t                  eg_intr_md,
    in    egress_intrinsic_metadata_from_parser_t      eg_prsr_md,
    inout egress_intrinsic_metadata_for_deparser_t     eg_dprsr_md,
    inout egress_intrinsic_metadata_for_output_port_t  eg_oport_md)
{
    apply {
    }
}

    /*********************  D E P A R S E R  ************************/

control EgressDeparser(packet_out pkt,
    /* User */
    inout my_egress_headers_t                       hdr,
    in    my_egress_metadata_t                      meta,
    /* Intrinsic */
    in    egress_intrinsic_metadata_for_deparser_t  eg_dprsr_md)
{
    apply {
        pkt.emit(hdr);
    }
}


/************ F I N A L   P A C K A G E ******************************/
Pipeline(
    IngressParser(),
    Ingress(),
    IngressDeparser(),
    EgressParser(),
    Egress(),
    EgressDeparser()
) pipe;

Switch(pipe) main;
