#include <stdint.h>

/* Constants and structures used to generate the CFI test binaries. See also: Resources/Tests/PLCrashAsyncDwarfEncodingTests */

struct __attribute__((packed)) pl_cie_data {
    uint8_t version; /* Must be set to 1 or 3 -- 1=eh_frame, 3=DWARF3, 4=DWARF4 */
    
    uint8_t augmentation[7];
    
    uint8_t code_alignment_factor;
    uint8_t data_alignment_factor;
    uint8_t return_address_register;
    
    uint8_t augmentation_data[6];
    
    uint8_t initial_instructions[0];
};

struct __attribute__((packed)) pl_fde_data_64 {
    uint64_t initial_location;
    uint64_t address_range;
    uint8_t instructions[];
};

struct __attribute__((packed)) pl_fde_data_32 {
    uint32_t initial_location;
    uint32_t address_range;
    uint8_t instructions[];
};


/* 32-bit and 64-bit length headers */
struct pl_cfi_header_32 {
    uint32_t length;
    uint32_t cie_id;
} __attribute__((packed));

struct pl_cfi_header_64 {
    uint32_t flag64; /* Must be set to 0xffffffff */
    uint64_t length;
    uint64_t cie_id;
} __attribute__((packed));

/* Mock entry */
typedef union pl_cfi_entry {
    struct {
        struct pl_cfi_header_64 hdr;
        union {
	        struct pl_cie_data cie;
            struct pl_fde_data_64 fde;
        };
    } e64;
    struct {
        struct pl_cfi_header_32 hdr;
        union {
	        struct pl_cie_data cie;
            struct pl_fde_data_32 fde;
        };
    } e32;
} pl_cfi_entry;

/* Initial length field size */
#define PL_CFI_LEN_SIZE_64 (sizeof(uint32_t) + sizeof(uint64_t))
#define PL_CFI_LEN_SIZE_32 (sizeof(uint32_t))

/* CFE lengths, minus the initial length field. */
#define PL_CFI_SIZE_64 (sizeof(pl_cfi_entry) - PL_CFI_LEN_SIZE_64)
#define PL_CFI_SIZE_32 (sizeof(pl_cfi_entry) - PL_CFI_LEN_SIZE_32)

/* PC values to be used when searching for FDE entries. */
#define PL_CFI_EH_FRAME_PC 0x60
#define PL_CFI_EH_FRAME_PC_RANGE 0x10

#define PL_CFI_DEBUG_FRAME_PC 0x30
#define PL_CFI_DEBUG_FRAME_PC_RANGE 0x10
