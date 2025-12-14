/// Module: hello_nasun
/// Nasun Devnet의 첫 번째 스마트 컨트랙트
module hello_nasun::hello {
    use std::string::{Self, String};

    /// Greeting 객체 - 인사 메시지를 저장
    public struct Greeting has key, store {
        id: UID,
        message: String,
        created_by: address,
    }

    /// 새로운 Greeting 객체 생성
    public entry fun create_greeting(
        message: vector<u8>,
        ctx: &mut TxContext
    ) {
        let greeting = Greeting {
            id: object::new(ctx),
            message: string::utf8(message),
            created_by: ctx.sender(),
        };
        transfer::public_transfer(greeting, ctx.sender());
    }

    /// Greeting 메시지 업데이트
    public entry fun update_greeting(
        greeting: &mut Greeting,
        new_message: vector<u8>,
    ) {
        greeting.message = string::utf8(new_message);
    }

    /// Greeting 메시지 읽기
    public fun get_message(greeting: &Greeting): &String {
        &greeting.message
    }

    /// Greeting 생성자 주소 읽기
    public fun get_creator(greeting: &Greeting): address {
        greeting.created_by
    }
}
