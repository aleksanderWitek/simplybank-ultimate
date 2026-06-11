package com.simplybank.simplybank_ultimate;

import org.springframework.boot.SpringApplication;

public class TestSimplybankUltimateApplication {

	public static void main(String[] args) {
		SpringApplication.from(SimplybankUltimateApplication::main).with(TestcontainersConfiguration.class).run(args);
	}

}
