package com.charlibot.templated.mail;

import com.github.mustachejava.DefaultMustacheFactory;
import com.github.mustachejava.MustacheFactory;
import com.charlibot.templated.mail.model.TemplateDetailResponse;
import lombok.val;
import org.springframework.beans.factory.SmartInitializingSingleton;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

@SpringBootApplication
public class Application {

  public static void main(String[] args) {
    SpringApplication.run(Application.class, args);
  }

  @Bean
  public MustacheFactory mustacheFactory() {
    return new DefaultMustacheFactory();
  }

  @Bean
  public SmartInitializingSingleton addSomeTemplates(final TemplatesRepository templatesRepository) {
    return () -> {
      val templateDetailResponse = new TemplateDetailResponse();
      templateDetailResponse.setTemplateId(1);
      templateDetailResponse.setName("First template");
      templateDetailResponse.setAlias("first-template");
      templateDetailResponse.setSubject("Hello from {{company.name}}");
      templateDetailResponse.setHtmlBody("<html><body>Hello {{name}}<body><html>");
      templateDetailResponse.setTextBody("Hello {{name}}");
      templateDetailResponse.setActive(true);
      templatesRepository.insertTemplate(templateDetailResponse);

      val templateDetailResponse2 = new TemplateDetailResponse();
      templateDetailResponse2.setTemplateId(2);
      templateDetailResponse2.setName("Second template");
      templateDetailResponse2.setAlias("second-template");
      templateDetailResponse2.setSubject("Goodbye from {{company.name}}");
      templateDetailResponse2.setHtmlBody("<html><body>Goodbye {{name}}<body><html>");
      templateDetailResponse2.setTextBody("Goodbye {{name}}");
      templateDetailResponse2.setActive(false);
      templatesRepository.insertTemplate(templateDetailResponse2);
    };
  }
}
