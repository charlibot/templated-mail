package com.charlibot.templated.mail;

import com.github.mustachejava.MustacheFactory;
import com.charlibot.templated.mail.model.EmailRenderResponse;
import com.charlibot.templated.mail.model.MultipartBody;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import lombok.val;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.servlet.HandlerMapping;

import javax.servlet.http.HttpServletRequest;
import java.io.StringReader;
import java.io.StringWriter;

@Slf4j
@Controller
@RequiredArgsConstructor
public class RenderingsController {

  private final TemplatesRepository templatesRepository;
  private final MustacheFactory mustacheFactory;

  // NOTE: We cannot use the generated API because if the templateAlias contains slashes we will get a 404.
  @RequestMapping(value = "/v1.0/renderings/**",
          produces = { "application/json" },
          consumes = { "application/json" },
          method = RequestMethod.PUT)
  public ResponseEntity<EmailRenderResponse> renderings(final HttpServletRequest httpServletRequest, @RequestBody final Object body) {
    val path = (String) httpServletRequest.getAttribute(HandlerMapping.PATH_WITHIN_HANDLER_MAPPING_ATTRIBUTE);
    val templateAlias = path.substring("/v1.0/renderings/".length());
    log.info("Finding template for alias {}", templateAlias);
    val templateOption = templatesRepository.listTemplates().stream().filter(t -> templateAlias.equals(t.getAlias())).findFirst();
    if (templateOption.isEmpty()) {
      throw new IllegalArgumentException("Cannot find template with alias: " + templateAlias);
    }
    val template = templateOption.get();
    val htmlBody = compile(template.getHtmlBody(), body);
    val textBody = compile(template.getTextBody(), body);
    val subject = compile(template.getSubject(), body);

    val multipartBody = new MultipartBody();
    multipartBody.setHtml(htmlBody);
    multipartBody.setPlain(textBody);

    val emailRenderResponse = new EmailRenderResponse();
    // TODO: where will these values come from?
    emailRenderResponse.fromAddress("someone@example.com");
    emailRenderResponse.fromDisplayName("Someone");
    emailRenderResponse.subject(subject);
    emailRenderResponse.setBody(multipartBody);

    return ResponseEntity.ok(emailRenderResponse);
  }

  private String compile(final String templateBody, final Object templateModel) {
    val mustache = mustacheFactory.compile(new StringReader(templateBody), "body");
    val stringWriter = new StringWriter();
    mustache.execute(stringWriter, templateModel);
    return stringWriter.toString();
  }
}
