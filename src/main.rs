mod ips;
mod utils;

use ips::patch_ips;

use std::env;

fn main() {
    let args: Vec<_> = env::args().skip(1).collect();

    if args.len() < 3 {
        println!("alps SOURCE PATCH OUTPUT");
    } else {
        let src_file = &args[0];
        let patch_file = &args[1];
        let out_file = &args[2];

        let result = patch_ips(src_file, patch_file, out_file);
        match result {
            Ok(()) => println!("Patch generated!"),
            Err(e) => println!("Error: {}", e)
        }
    }
}
