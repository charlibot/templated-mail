package com.charlibot.templated.mail;

import com.charlibot.templated.mail.api.TemplatesApiDelegate;
import com.charlibot.templated.mail.model.CreateTemplateRequest;
import com.charlibot.templated.mail.model.TemplateDetailResponse;
import com.charlibot.templated.mail.model.TemplateListingResponse;
import com.charlibot.templated.mail.model.TemplateRecordResponse;
import com.charlibot.templated.mail.model.UpdateTemplateRequest;
import lombok.RequiredArgsConstructor;
import lombok.val;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;

import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class TemplatesDelegate implements TemplatesApiDelegate {

  private final TemplatesRepository templatesRepository;

  @Override
  public ResponseEntity<TemplateDetailResponse> createTemplate(CreateTemplateRequest createTemplateRequest) {
    val templateDetailResponse = new TemplateDetailResponse();
    templateDetailResponse.setActive(true);
    templateDetailResponse.setHtmlBody(createTemplateRequest.getHtmlBody());
    templateDetailResponse.setTextBody(createTemplateRequest.getTextBody());
    templateDetailResponse.setName(createTemplateRequest.getName());
    templateDetailResponse.setSubject(createTemplateRequest.getSubject());
    templateDetailResponse.setTemplateId(templatesRepository.listTemplates().size() + 1);
    templateDetailResponse.setAlias(createTemplateRequest.getAlias());
    templatesRepository.insertTemplate(templateDetailResponse);
    return ResponseEntity.ok(templateDetailResponse);
  }

  @Override
  public ResponseEntity<TemplateDetailResponse> updateTemplate(Integer templateId, UpdateTemplateRequest updateTemplateRequest) {
    val template = templatesRepository.getTemplateById(templateId);
    template.setName(updateTemplateRequest.getName());
    template.setSubject(updateTemplateRequest.getSubject());
    template.setHtmlBody(updateTemplateRequest.getHtmlBody());
    template.setTextBody(updateTemplateRequest.getTextBody());
    templatesRepository.insertTemplate(template);
    return ResponseEntity.ok(template);
  }

  @Override
  public ResponseEntity<TemplateDetailResponse> getSingleTemplate(Integer templateId) {
    return ResponseEntity.ok(templatesRepository.getTemplateById(templateId));
  }

  @Override
  public ResponseEntity<TemplateListingResponse> listTemplates() {
    val templates = templatesRepository.listTemplates().stream().map(this::detailedToRecord).collect(Collectors.toList());
    val listingResponse = new TemplateListingResponse();
    listingResponse.setTotalCount(templates.size());
    listingResponse.setTemplates(templates);
    return ResponseEntity.ok(listingResponse);
  }

  private TemplateRecordResponse detailedToRecord(final TemplateDetailResponse templateDetailResponse) {
    val templateRecordResponse = new TemplateRecordResponse();
    templateRecordResponse.setTemplateId(templateDetailResponse.getTemplateId());
    templateRecordResponse.setName(templateDetailResponse.getName());
    templateRecordResponse.setActive(templateDetailResponse.getActive());
    templateRecordResponse.setAlias(templateDetailResponse.getAlias());
    return templateRecordResponse;
  }
}
