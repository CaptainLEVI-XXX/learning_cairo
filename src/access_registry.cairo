use core::starknet::contract_address::ContractAddress;

#[starknet::interface]
pub trait IAccess_registrable<TContractState> {
    fn add_owner(ref self: TContractState, new_owner_: ContractAddress);
    fn remove_owner(ref self: TContractState,remove_owner: ContractAddress);
    fn transfer_signature(ref self: TContractState, new_owner_:ContractAddress);
    fn is_owner(self: @TContractState,caller:ContractAddress)->bool;  
    fn required_owners(self: @TContractState)->u256;
    fn admin_of_wallet(self: @TContractState)->ContractAddress;
    fn total_owners_of_Wallet(self : @TContractState)->u256;
}

#[starknet::component]
pub mod Access_registrable{
    use super::IAccess_registrable;
    use starknet::{
        ContractAddress,get_caller_address
    };
    use core::num::traits::Zero;

    #[storage]
    struct Storage {
        owners: LegacyMap::<ContractAddress, bool>,
        admin: ContractAddress,
        number_of_owners_required: u256,
        total_owners: u256
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        owner_addition: owner_addition,
        owner_removal: owner_removal,
        transfer_signatory: transfer_signatory
    }


    #[derive(Drop, starknet::Event)]
    pub struct owner_addition{
        #[key]
        pub added_owner:ContractAddress

    }

    #[derive(Drop, starknet::Event)]
    pub struct owner_removal{
        #[key]
        pub removed_owner:ContractAddress
        
    }

    #[derive(Drop, starknet::Event)]
    pub struct transfer_signatory{
        pub prev_owner :ContractAddress,
        pub new_owner :ContractAddress        
    }

    pub mod Errors {
        pub const NOT_OWNER: felt252 = 'Caller is not the owner';
        pub const ALREADY_OWNER: felt252 = 'Caller is Already owner';
        pub const ZERO_ADDRESS_CALLER: felt252 = 'Caller is the zero address';

    }


    #[embeddable_as(Access_Registrable)] 
    pub impl AccessRegistrableImpl <TContractState,+HasComponent<TContractState>
    >of super::IAccess_registrable<ComponentState<TContractState>> {
        
        fn add_owner(ref self: ComponentState<TContractState>, new_owner_: ContractAddress){
           
            self.call_by_admin(get_caller_address());
            self.owners.write(new_owner_,true);
            self.total_owners.write(self.total_owners.read() + 1);
            self.update_required_owners();
            self.emit(Event::owner_addition(owner_addition{added_owner: new_owner_}));

        } 
        fn remove_owner(ref self:ComponentState<TContractState>,remove_owner: ContractAddress){

            let caller = get_caller_address();

            self.call_by_admin(caller);
            self.owners.write(remove_owner,false);
            self.total_owners.write(self.total_owners.read() - 1);
            self.update_required_owners();
            self.emit(Event::owner_removal(owner_removal{removed_owner: remove_owner}))

        }

        fn transfer_signature(ref self:ComponentState<TContractState>, new_owner_:ContractAddress){
            
            let  caller = get_caller_address();

            assert(self.is_owner(caller),Errors::NOT_OWNER);
            assert(self.is_owner(new_owner_) != true,Errors::ALREADY_OWNER);
            self.owners.write(caller,false);
            self.owners.write(new_owner_,true);

            self.emit(Event::transfer_signatory(transfer_signatory{
                prev_owner: caller,
                new_owner:new_owner_
            }));

        }

        fn is_owner(self: @ComponentState<TContractState>, caller:ContractAddress)->bool{
            self.owners.read(caller)
        }

        fn required_owners(self: @ComponentState<TContractState>)->u256{
            self.number_of_owners_required.read()
        }
        fn admin_of_wallet(self : @ComponentState<TContractState>)->ContractAddress{
            self.admin.read()
        }

        fn total_owners_of_Wallet(self : @ComponentState<TContractState>)->u256{
            self.total_owners.read()
        }


    }

    #[generate_trait]
    pub impl Access_registrable_PrivateImpl<
            TContractState, +HasComponent<TContractState>
            >of InternalTrait<TContractState>{

        fn update_required_owners(ref self: ComponentState<TContractState>){    
            self.number_of_owners_required.write(self.ceil(60 * self.total_owners.read(), 100));
        }

        fn call_by_admin(self: @ComponentState<TContractState>, caller_:ContractAddress){
            assert(caller_ == self.admin.read(),'NOT_ADMIN');
        }

        fn _init(ref self: ComponentState<TContractState>, _admin: ContractAddress){

            assert(_admin != Zero::zero(),Errors::ZERO_ADDRESS_CALLER);
            self.admin.write(_admin);

        }

        fn ceil(self: @ComponentState<TContractState>,a:u256, b:u256)->u256{
            if a%b==0{
                return a/b;
            }
            a/b+1
        }

    }
}

