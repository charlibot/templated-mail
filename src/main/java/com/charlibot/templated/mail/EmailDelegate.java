package com.charlibot.templated.mail;

import com.github.mustachejava.MustacheFactory;
import com.sendgrid.Method;
import com.sendgrid.Request;
import com.sendgrid.SendGrid;
import com.sendgrid.helpers.mail.Mail;
import com.sendgrid.helpers.mail.objects.Content;
import com.sendgrid.helpers.mail.objects.Email;
import com.charlibot.templated.mail.api.EmailApiDelegate;
import com.charlibot.templated.mail.model.EmailWithTemplateRequest;
import com.charlibot.templated.mail.model.SendEmailResponse;
import lombok.RequiredArgsConstructor;
import lombok.SneakyThrows;
import lombok.extern.slf4j.Slf4j;
import lombok.val;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;

import java.io.StringReader;
import java.io.StringWriter;
import java.time.OffsetDateTime;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class EmailDelegate implements EmailApiDelegate {

  private final TemplatesRepository templatesRepository;
  private final MustacheFactory mustacheFactory;
  private final SendGrid sendGrid;

  @Override
  public ResponseEntity<SendEmailResponse> sendEmailWithTemplate(EmailWithTemplateRequest emailWithTemplateRequest) {
    val template = templatesRepository.getTemplateById(emailWithTemplateRequest.getTemplateId());
    if (template == null) {
      return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).build();
    }
    val htmlBody = compile(template.getHtmlBody(), emailWithTemplateRequest.getTemplateModel());
    val textBody = compile(template.getTextBody(), emailWithTemplateRequest.getTemplateModel());
    val subject = compile(template.getSubject(), emailWithTemplateRequest.getTemplateModel());

    sendEmail(emailWithTemplateRequest.getFrom(), emailWithTemplateRequest.getTo(), subject, htmlBody, textBody);

    val response = new SendEmailResponse();
    response.setMessageID(UUID.randomUUID().toString());
    response.setSubmittedAt(OffsetDateTime.now());
    response.setTo(emailWithTemplateRequest.getTo());
    return ResponseEntity.ok(response);
  }

  private String compile(final String templateBody, final Object templateModel) {
    val mustache = mustacheFactory.compile(new StringReader(templateBody), "body");
    val stringWriter = new StringWriter();
    mustache.execute(stringWriter, templateModel);
    return stringWriter.toString();
  }

  @SneakyThrows
  private void sendEmail(final String from, final String to, final String subject, final String html, final String text) {
    val htmlContent = new Content("text/html", html);
    val textContent = new Content("text/plain", text);
    val mail = new Mail(new Email(from), subject, new Email(to), textContent);
    mail.addContent(htmlContent);
    val request = new Request();
    request.setMethod(Method.POST);
    request.setEndpoint("mail/send");
    request.setBody(mail.build());
    val response = sendGrid.api(request);
    log.info("Response from sendgrid. Status={}, body={}", response.getStatusCode(), response.getBody());
    if (response.getStatusCode() != 202) {
      throw new IllegalArgumentException();
    }
  }
}
